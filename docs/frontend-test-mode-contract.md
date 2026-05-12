# Frontend Test Mode Contract

How to build test-only frontend components that bypass real Whop checkout UI while still exercising your backend payment flows.

---

## Overview

In test mode, your frontend swaps real Whop embedded components with fake UI that:

1. Renders a simple form/buttons (no iframes, no Whop.js)
2. Calls a **test-only Rails controller** to generate tokens
3. POSTs those tokens to your **real backend endpoints**
4. Invokes the same callbacks the production components would

This mirrors how you currently use `TestPayments.tsx` / `TestBillingStripeElements.tsx` with Stripe.

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│  Frontend (Test Mode)                                           │
│                                                                  │
│  TestWhopCheckout.tsx                                           │
│    ├── renders fake card form                                   │
│    ├── POST /testing_mocks/whop/tokens  ──────────────────┐     │
│    │        (get payment token)                           │     │
│    ├── POST /testing_mocks/whop/checkout_configs  ────────┤     │
│    │        (get checkout config)                         │     │
│    └── POST /api/web/v1/.../payments/buy  ────────────────┤     │
│             (real backend endpoint)                       │     │
└───────────────────────────────────────────────────────────│─────┘
                                                            │
┌───────────────────────────────────────────────────────────▼─────┐
│  Backend (Rails)                                                 │
│                                                                  │
│  TestingMocksController (test-only)                             │
│    ├── POST /tokens      → WhopMock.generate_payment_token      │
│    └── POST /checkout_configs → WhopMock SDK call               │
│                                                                  │
│  PaymentsController (real)                                      │
│    └── POST /buy         → WhopSDK::Client (intercepted by mock)│
└──────────────────────────────────────────────────────────────────┘
```

---

## 1. Payment Token Generation

### Contract

Your test component needs a token to simulate card entry.

**Request:**
```
POST /api/web/v1/testing_mocks/whop/tokens
Content-Type: application/json

{
  "last4": "4242",
  "exp_month": 12,
  "exp_year": 2030,
  "brand": "visa",
  "country": "US"
}
```

**Response:**
```json
{
  "id": "tok_abc123xyz",
  "type": "payment_token",
  "last4": "4242",
  "exp_month": 12,
  "exp_year": 2030,
  "brand": "visa",
  "country": "US",
  "created_at": "2026-05-01T12:00:00Z"
}
```

### Rails Controller

```ruby
# app/controllers/api/web/v1/testing_mocks/whop_controller.rb
class Api::Web::V1::TestingMocks::WhopController < ApplicationController
  before_action :ensure_test_mode!

  def create_token
    token = WhopMock.generate_payment_token(
      last4: params[:last4] || "4242",
      exp_month: params[:exp_month] || 12,
      exp_year: params[:exp_year] || 2030,
      brand: params[:brand] || "visa",
      country: params[:country] || "US"
    )
    render json: token
  end

  private

  def ensure_test_mode!
    raise "Not in test mode" unless Rails.env.test?
  end
end
```

### How the Mock Handles It

When your real backend later calls:

```ruby
client.payment_methods.create(
  company_id: "biz_xxx",
  token_id: "tok_abc123xyz"  # from generate_payment_token
)
```

The mock:
1. Looks up the token in `payment_token` store
2. Expands token attributes into the payment method
3. Returns a real `WhopSDK::PaymentMethod` object

---

## 2. Checkout Configuration

### Contract

For checkout flows, create a checkout configuration that your test UI references.

**Request:**
```
POST /api/web/v1/testing_mocks/whop/checkout_configs
Content-Type: application/json

{
  "company_id": "biz_xxx",
  "mode": "payment",
  "plan_id": "plan_yyy",
  "redirect_url": "https://example.com/success",
  "allow_promo_codes": true
}
```

**Response:**
```json
{
  "id": "chkout_abc123",
  "company_id": "biz_xxx",
  "mode": "payment",
  "plan_id": "plan_yyy",
  "redirect_url": "https://example.com/success",
  "allow_promo_codes": true,
  "purchase_url": "https://whop.com/checkout/chkout_abc123",
  "created_at": "2026-05-01T12:00:00Z"
}
```

### Rails Controller

```ruby
def create_checkout_config
  # This goes through the real SDK (intercepted by mock)
  config = whop_client.checkout_configurations.create(
    company_id: params[:company_id],
    mode: params[:mode] || "payment",
    plan_id: params[:plan_id],
    redirect_url: params[:redirect_url],
    allow_promo_codes: params[:allow_promo_codes]
  )
  render json: config.to_h
end

private

def whop_client
  @whop_client ||= WhopSDK::Client.new(access_token: "test_token")
end
```

### Modes

| Mode | Use Case |
|------|----------|
| `payment` | One-time purchase or subscription signup |
| `setup` | Save card for later (no immediate charge) |

---

## 3. Test Component Example

```tsx
// app/assets/javascripts/.../TestWhopCheckout.tsx

import React, { useState } from "react";

interface Props {
  companyId: string;
  planId: string;
  onSuccess: (result: { membershipId: string; paymentId: string }) => void;
  onError: (error: Error) => void;
}

export const TestWhopCheckout: React.FC<Props> = ({
  companyId,
  planId,
  onSuccess,
  onError,
}) => {
  const [cardScenario, setCardScenario] = useState<"valid" | "declined">("valid");

  const handleSubmit = async () => {
    try {
      // 1. Generate payment token
      const tokenRes = await fetch("/api/web/v1/testing_mocks/whop/tokens", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          last4: cardScenario === "valid" ? "4242" : "0002",
          brand: "visa",
        }),
      });
      const token = await tokenRes.json();

      // 2. Call real backend buy endpoint with token
      const buyRes = await fetch(`/api/web/v1/spaces/${companyId}/payments/buy`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          plan_id: planId,
          payment_token_id: token.id,
        }),
      });

      if (!buyRes.ok) {
        throw new Error("Payment failed");
      }

      const result = await buyRes.json();
      onSuccess({
        membershipId: result.membership_id,
        paymentId: result.payment_id,
      });
    } catch (err) {
      onError(err as Error);
    }
  };

  return (
    <div data-testid="test-whop-checkout">
      <h3>Test Whop Checkout</h3>

      <div>
        <label>
          <input
            type="radio"
            checked={cardScenario === "valid"}
            onChange={() => setCardScenario("valid")}
          />
          Valid Card (4242)
        </label>
        <label>
          <input
            type="radio"
            checked={cardScenario === "declined"}
            onChange={() => setCardScenario("declined")}
          />
          Declined Card (0002)
        </label>
      </div>

      <button onClick={handleSubmit}>
        Complete Purchase
      </button>
    </div>
  );
};
```

---

## 4. Simulating Errors

### Declined Card

Use `WhopMock.prepare_error` before the test:

```ruby
# spec/features/checkout_spec.rb
before do
  WhopMock.prepare_error(:bad_request, :create_payment, message: "Card declined")
end

it "shows error when card is declined" do
  visit checkout_path
  click_button "Complete Purchase"
  expect(page).to have_text("Card declined")
end
```

### Error Scenarios

| Scenario | Error Key | Action Key |
|----------|-----------|------------|
| Card declined | `:bad_request` | `:create_payment` |
| Invalid card | `:unprocessable_entity` | `:create_payment_method` |
| Rate limited | `:rate_limit` | any |
| Auth failed | `:authentication` | any |

---

## 5. Setup Intent Flow (Save Card)

For save-card-for-later flows:

```tsx
const handleSaveCard = async () => {
  // 1. Create checkout config in setup mode
  const configRes = await fetch("/api/web/v1/testing_mocks/whop/checkout_configs", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      company_id: companyId,
      mode: "setup",  // <-- setup mode, not payment
    }),
  });
  const config = await configRes.json();

  // 2. Generate token
  const tokenRes = await fetch("/api/web/v1/testing_mocks/whop/tokens", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ last4: "4242" }),
  });
  const token = await tokenRes.json();

  // 3. Attach payment method to member
  const attachRes = await fetch(`/api/web/v1/members/${memberId}/payment_methods`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      checkout_configuration_id: config.id,
      payment_token_id: token.id,
    }),
  });

  // ...
};
```

---

## 6. ID Formats

| Resource | Prefix | Example |
|----------|--------|---------|
| Payment Token | `tok_` | `tok_abc123xyz` |
| Checkout Config | `chkout_` | `chkout_def456` |
| Payment Method | `pm_` | `pm_ghi789` |
| Payment | `pay_` | `pay_jkl012` |
| Membership | `mem_` | `mem_mno345` |
| Invoice | `inv_` | `inv_pqr678` |
| Company | `biz_` | `biz_stu901` |
| Plan | `plan_` | `plan_vwx234` |

---

## 7. Branching in Production Code

```tsx
// app/assets/javascripts/.../BundleBuyView.tsx

import { WhopCheckout } from "@whop/react";  // Real component
import { TestWhopCheckout } from "./TestWhopCheckout";

export const BundleBuyView: React.FC<Props> = (props) => {
  if (process.env.NODE_ENV === "test" || window.__WHOP_TEST_MODE__) {
    return <TestWhopCheckout {...props} />;
  }

  return <WhopCheckout {...props} />;
};
```

---

## 8. Webhook Simulation

After a payment succeeds in tests, simulate the webhook:

```ruby
# In your test
payment = WhopMock.session.store.find("payment", payment_id)

event = WhopMock.mock_webhook_event("payment.succeeded", {
  data: { id: payment["id"] }
})

# POST to your webhook handler
post "/api/integrations/whop/events",
  params: event.to_json,
  headers: WhopMock.sign_webhook(event, secret: "whsec_test")["headers"]
```

---

## Summary

| What You Need | How to Get It |
|---------------|---------------|
| Fake card token | `WhopMock.generate_payment_token(last4: "4242")` |
| Checkout object | `client.checkout_configurations.create(...)` |
| Simulate errors | `WhopMock.prepare_error(:bad_request, :create_payment)` |
| Webhook payload | `WhopMock.mock_webhook_event("payment.succeeded", ...)` |
| Signed webhook | `WhopMock.sign_webhook(payload, secret: "...")` |

Your test components don't need a Whop React package — just POST to test controllers that call these mock helpers, then hit your real backend endpoints.
