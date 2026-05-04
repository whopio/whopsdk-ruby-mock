# WhopMock

Stateful in-process mock for the Whop Ruby SDK. Like `stripe-ruby-mock` but for Whop.

## Install

```ruby
# Gemfile
group :test do
  gem "whop_mock"
  gem "whop_sdk"
end
```

## Quick Start

```ruby
require "whop_mock"
require "whop_sdk"

RSpec.configure do |config|
  config.before(:each) { WhopMock.start }
  config.after(:each)  { WhopMock.stop }
end
```

```ruby
it "cancels a membership" do
  client = WhopSDK::Client.new(api_key: "test_key")
  WhopMock.install!(client)

  WhopMock.seed("membership", { "id" => "mbr_123", "status" => "active" })

  membership = client.memberships.retrieve("mbr_123")
  expect(membership.status).to eq("active")

  client.memberships.cancel("mbr_123")
  expect(client.memberships.retrieve("mbr_123").status).to eq("canceled")
end
```

## Coverage

Billing: `companies`, `memberships`, `payments`, `invoices`, `refunds`, `payment_methods`, `plans`, `products`, `promo_codes`, `checkout_configurations`, `disputes`, `webhooks`

Payouts: `account_links`, `fee_markups`, `ledger_accounts`, `payout_accounts`, `transfers`, `topups`, `withdrawals`

Not covered: `affiliates`, `apps`, `chat_channels`, `users`

See [coverage-matrix.md](docs/coverage-matrix.md) for details.

## API

### Lifecycle

```ruby
WhopMock.start                    # Start session
WhopMock.stop                     # End session
WhopMock.install!(client)         # Intercept SDK client
WhopMock.uninstall!(client)       # Restore SDK client
```

### Seeding Data

```ruby
WhopMock.seed("company", { "id" => "biz_123", "title" => "Acme" })
WhopMock.seed_many("membership", [{ "status" => "active" }, { "status" => "past_due" }])
WhopMock.load_fixtures("spec/fixtures/seeds.yml")
WhopMock.generate_example("membership", { "status" => "trialing" })
```

### Error Injection

```ruby
WhopMock.prepare_error(:not_found, :retrieve_membership)
WhopMock.prepare_error(StandardError, :create_payment, message: "declined")
```

### Webhooks

```ruby
event = WhopMock.mock_webhook_event("membership.activated", { data: { id: "mbr_123" } })
signed = WhopMock.sign_webhook(event, secret: "whsec_test")
```

### Payment Tokens

```ruby
token = WhopMock.generate_payment_token(last4: "4242", brand: "visa")
```

### Fallback Handlers

```ruby
WhopMock.register_fallback do |method:, path:, query:, body:|
  [200, { "ok" => true }] if path == "/custom/endpoint"
end
```

### Debug Mode

```ruby
WhopMock.toggle_debug(true)
```

## OpenAPI Sync

The mock auto-derives routes from the Stainless-hosted OpenAPI spec:

```bash
./scripts/sync_openapi
```

## Compatibility

- Ruby `3.4.5`
- `whop_sdk` gem `0.0.38`

## Docs

- [Coverage Matrix](docs/coverage-matrix.md)
- [Compatibility Matrix](docs/compatibility-matrix.md)
- [SDK Surface Audit](docs/sdk-surface-audit.md)
- [Frontend Test Mode](docs/frontend-test-mode-contract.md)
