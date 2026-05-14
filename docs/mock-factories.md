# Mock Factories

Documented public mock-object factory surface for generating test data. This is the closest equivalent to `StripeMock::Data.mock_*`, but expressed as `WhopMock.create_test_helper` plus direct `seed` and `generate_example` helpers.

## Test Helper Factories

```ruby
helper = WhopMock.create_test_helper

company = helper.create_company("title" => "Acme")
product = helper.create_product("company_id" => company["id"], "title" => "Starter")
plan = helper.create_plan("company_id" => company["id"], "product_id" => product["id"], "title" => "Monthly")
membership = helper.create_membership("company_id" => company["id"], "plan_id" => plan["id"])
payment = helper.create_payment("company_id" => company["id"], "plan_id" => plan["id"])
invoice = helper.create_invoice("company_id" => company["id"])
refund = helper.create_refund(payment["id"])
stack = helper.create_billing_stack
failed = helper.create_failed_renewal
refunded = helper.create_refunded_payment
```

These helpers create coherent linked records rather than isolated rows, which is usually what larger integration suites need.

## Seeding Records

```ruby
# Seed a single record
WhopMock.seed("membership", { "id" => "mbr_123", "status" => "active" })

# Seed multiple records
WhopMock.seed_many("payment", [
  { "status" => "paid", "amount" => 1000 },
  { "status" => "failed", "amount" => 500 }
])

# Load from YAML fixture
WhopMock.load_fixtures("spec/fixtures/seeds.yml")
```

## Generating Examples

Auto-generate valid records from OpenAPI schema:

```ruby
# Generate with defaults
membership = WhopMock.generate_example("membership")

# Generate with overrides
membership = WhopMock.generate_example("membership", { "status" => "trialing" })
```

## Payment Tokens

```ruby
token = WhopMock.generate_payment_token(
  last4: "4242",
  brand: "visa",
  exp_month: 12,
  exp_year: 2030
)
```

## Webhooks

```ruby
# Create mock event
event = WhopMock.mock_webhook_event("membership.activated", {
  data: { id: "mbr_123", status: "active" }
})

# Sign for verification
signed = WhopMock.sign_webhook(event, secret: "whsec_test")
```

## Supported Resources

Current documented factory-friendly focus:

| Category | Resources |
|----------|-----------|
| Billing | `companies`, `members`, `memberships`, `payments`, `payment_methods`, `invoices`, `refunds`, `plans`, `products`, `promo_codes`, `checkout_configurations`, `disputes`, `dispute_alerts`, `setup_intents`, `webhooks` |
| Payouts | `account_links`, `fee_markups`, `ledger_accounts`, `payout_accounts`, `payout_methods`, `transfers`, `topups`, `withdrawals` |

For the authoritative covered vs uncovered SDK surface, see [Coverage Matrix](coverage-matrix.md).
