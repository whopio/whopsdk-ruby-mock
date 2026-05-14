# WhopMock Coverage Matrix

This is the current implementation and verification matrix for `whop_mock` against the published `whop_sdk` surface.

Verification sources:

- direct mock-level specs in `spec/whop_mock_spec.rb`
- real SDK integration specs in `spec/whop_sdk_integration_spec.rb`
- adversarial multi-step flows in `spec/stress/speckel_style_stress_spec.rb`

Current suite status:

- `mise exec ruby@3.4.5 -- bundle exec rspec`
- `122 examples, 0 failures`

Spec source:

- Active contract artifact: `vendor/openapi/whop-openapi.yml` when present
- Repo fallback contract: `spec/fixtures/openapi.yml`
- Refresh or replace the vendored artifact with: `./scripts/sync_openapi`

SDK basis:

- published `whop_sdk 0.0.38`

## Resource Coverage

| Resource | Public SDK surface covered | Real SDK-tested | Create validation | Update/action validation | List/filter coverage | Webhook coverage | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `account_links` | `create` | Yes | Schema-backed create validation | N/A | N/A | Indirect only | Real create-only Whop SDK surface for hosted onboarding/payout portal links |
| `companies` | `create`, `retrieve`, `list`, `update` | Yes | Yes | Basic update only | Yes | Indirect only | No delete in current SDK surface |
| `checkout_configurations` | `create`, `retrieve`, `list` | Yes | Schema-backed create shape plus graph shaping | N/A | `company_id`, `plan_id`, `created_after`, `created_before`, `direction` | Indirect only | Covers payment-mode and setup-mode checkout flows with real SDK types |
| `dispute_alerts` | `retrieve`, `list` | Yes | N/A | N/A | `company_id`, creation window, direction | Indirect only | Early-warning risk surface with nested dispute/payment context |
| `disputes` | `retrieve`, `list`, `update_evidence`, `submit_evidence` | Yes | N/A | Evidence update plus submit transition validation | `company_id`, creation window, direction | Indirect only | Read-heavy payment-risk surface with editable/under-review transition coverage |
| `fee_markups` | `create`, `list`, `delete` | Yes | Schema-backed create validation plus upsert semantics | N/A | `company_id` required | Indirect only | Real backend fee override surface; repeated create updates existing markup by `company_id + fee_type` |
| `ledger_accounts` | `retrieve` | Yes | N/A | N/A | N/A | Indirect only | Retrieve-only balance visibility surface with owner union, balances, approval status, and payout-account details |
| `members` | `retrieve`, `list` | Yes | N/A | N/A | Query/status/order/direction/access-level | Indirect only | Separate from `memberships`; useful for identity-centric setup |
| `products` | `create`, `retrieve`, `list`, `update`, `delete` | Yes | Yes | Basic update only | Yes | Indirect only | Negative-price validation does not apply |
| `plans` | `create`, `retrieve`, `list`, `update`, `delete` | Yes | Yes | Negative price validation | Yes | Indirect only | Product/company graph reuse covered |
| `memberships` | `retrieve`, `list`, `update`, `cancel`, `pause`, `resume`, `uncancel`, `add_free_days` | Yes | Partial | Transition validation | Yes | Yes | No public `create` method in current SDK |
| `payment_methods` | `retrieve`, `list` | Yes | Yes via mock requester path | N/A | Basic list | Indirect only | SDK surface has no public create method |
| `payout_accounts` | `retrieve` | Yes | N/A | N/A | N/A | Indirect only | Current SDK surface only exposes retrieve |
| `payout_methods` | `retrieve`, `list` | Yes | N/A | N/A | Basic list | Indirect only | `list` validation requires `company_id` |
| `payments` | `create`, `retrieve`, `list`, `list_fees`, `refund`, `retry_`, `void` | Yes | Yes | Refund/retry/void validation | Yes | Yes | Richest create-path coverage in repo |
| `invoices` | `create`, `retrieve`, `list`, `update`, `delete`, `mark_paid`, `mark_uncollectible`, `void` | Yes | Yes | Update/action validation | Yes | Yes | Same-member overlapping draft loops covered |
| `promo_codes` | `create`, `retrieve`, `list`, `delete` | Yes | Schema-backed create plus graph shaping | List validation | Yes | Indirect only | Real Whop SDK promo-code surface; company/product/plan scoping covered |
| `refunds` | `retrieve`, `list` | Yes | Indirect via payment refund flows | N/A | Yes | Yes | Partial and repeated refund paths covered |
| `setup_intents` | `retrieve`, `list` | Yes | N/A | N/A | Yes | Yes | Current SDK surface has no public create/update actions |
| `topups` | `create` | Yes | Schema-backed create validation | N/A | N/A | Indirect only | Payment-like company balance funding surface; amount and payment method validation covered |
| `transfers` | `create`, `retrieve`, `list` | Yes | Basic create plus schema enum checks | N/A | Basic list plus order/direction validation | Indirect only | Customer-adjacent payout surface now covered |
| `webhooks` | `create`, `retrieve`, `list`, `update`, `delete`, `unwrap` | Yes | Basic create validation via schema-backed shape | Basic update only | Yes | Core consumer path | Signed unwrap tested against real SDK |
| `withdrawals` | `create`, `retrieve`, `list` | Yes | Basic create | N/A | Basic list | Indirect only | `list` validation requires `company_id` |
| `events` | `retrieve` via mock event store | Indirect | N/A | N/A | N/A | Core producer path | Used to support fabricated webhook retrieval |

## Wider SDK Surface

The mock should still not be described as broad whole-SDK parity.

The more accurate description is:

- strong parity on the billing-oriented and payout-adjacent subset we intentionally targeted
- limited or no parity on adjacent product/application/chat/affiliate/user resource families
- no mock-only Stripe-shaped resource surfaces carried as SDK parity

### Current Billing-Focused Coverage

The current mock is strongest on:

- `account_links`
- `companies`
- `checkout_configurations`
- `dispute_alerts`
- `disputes`
- `fee_markups`
- `ledger_accounts`
- `members`
- `products`
- `plans`
- `memberships`
- `payment_methods`
- `payout_accounts`
- `payout_methods`
- `payments`
- `invoices`
- `promo_codes`
- `refunds`
- `setup_intents`
- `transfers`
- `topups`
- `webhooks`
- `withdrawals`

For those resources, the mock now covers:

- real `WhopSDK::Client` interception
- stateful create/retrieve/update/list/action behavior where those SDK methods exist
- list/filter support for the higher-value billing params we modeled
- create/update/action validation on the highest-risk billing paths
- webhook fabrication/signing and real SDK `unwrap`
- multi-step adversarial flows through the billing graph

### Public SDK Families Not Currently Covered

These public SDK families remain intentionally out of scope in the live mock:

- `affiliates`
- `apps`
- `chat_channels`
- `users`

Those are scope facts, not hidden parity gaps inside the current billing/payout target.

## Validation Coverage

### Create validation implemented

- `companies.create`
  - requires `title`
- `products.create`
  - requires `company_id`, `title`
- `plans.create`
  - requires `company_id`, `product_id`, `title`
  - negative price validation is currently on update, not create
- `payment_methods` mock create path
  - requires `payment_token` or `payment_token_id`
- `payments.create`
  - requires `company_id`, `member_id`
  - requires `plan_id/plan`
  - requires `payment_method_id/payment_method`
  - rejects conflicting `plan_id` vs `plan.id`
  - rejects conflicting `product_id` vs existing plan product
- `invoices.create`
  - requires `company_id`
  - requires `member_id` or `email_address`
  - requires `product_id/product/plan`
  - `charge_automatically` requires `payment_token_id`
  - rejects conflicting `product_id` vs `plan.product_id`

### Update/action validation implemented

- `plans.update`
  - rejects negative `initial_price`
  - rejects negative `renewal_price`
- `invoices.update`
  - rejects conflicting `product_id` vs `plan.product_id`
  - rejects `charge_automatically` without an available `payment_token_id`
- `memberships.pause`
  - rejects pause from `canceled` or already `paused`
- `memberships.resume`
  - rejects resume unless current status is `paused`
- `memberships.uncancel`
  - rejects uncancel unless current status is `canceled`
- `memberships.add_free_days`
  - rejects `free_days <= 0`
- `payments.refund`
  - rejects zero/negative refund amounts
  - rejects refund amount above remaining refundable amount
- `payments.retry_`
  - rejects retry outside `open` / failed / pending states
- `payments.void`
  - rejects void when already `void` or already refunded
- `invoices.mark_paid`
  - rejects for `paid`, `refunded`, `void`
- `invoices.mark_uncollectible`
  - rejects for `void`, `uncollectible`
  - intentionally still allowed from states our lifecycle/webhook tests depend on
- `invoices.void`
  - rejects for `void`, `refunded`

### List validation implemented

- `plans.list`
  - requires `company_id`
- `checkout_configurations.list`
  - requires `company_id`
- `disputes.list`
  - requires `company_id`
- `dispute_alerts.list`
  - requires `company_id`
- `fee_markups.list`
  - requires `company_id`
- `products.list`
  - requires `company_id`
- `setup_intents.list`
  - requires `company_id`
- `webhooks.list`
  - requires `company_id`
- `payment_methods.list`
  - requires exactly one of `company_id` or `member_id`
- `promo_codes.list`
  - requires `company_id`
  - validates `status`
- `members.list`
  - validates `access_level`
  - validates `statuses`
  - validates `most_recent_actions`
  - validates `order`
  - validates `direction`
- `payout_methods.list`
  - requires `company_id`
- `transfers.list`
  - validates `order`
  - validates `direction`
- `withdrawals.list`
  - requires `company_id`

## Stress Coverage

Current adversarial/stress flows cover:

- bootstrap company → product → plan → payment method → payment → invoice → membership
- repeated list/filter/search after mutations
- refund → uncollectible → retry → mark paid loops
- partial refund → final refund crossover
- create failure injection with clean state afterward
- same-member overlapping draft/update/create invoice loops
- create-heavy webhook fabrication and signed unwrap
- failure → retry → paid → partial refund → full refund for the same member

## Known Gaps

These are the main remaining parity gaps, ordered by likely customer impact.

### 1. Validation breadth is still selective

We now validate high-risk create/update/action flows and some schema-derived required/enumerated fields on the covered billing/payout surface, but not every resource/field combination. For example:

- unknown fields are silently ignored (permissive) to handle spec/SDK mismatches
- no deep numeric/range validation outside targeted billing fields
- no schema-wide nested contract validation for every covered object

### 2. Filter breadth is still selective

We cover many important filters, but not exhaustive parity for every SDK list param on every resource. Unknown customer filters may still return too many or too few records.

### 2a. Search is mock-native, not SDK-native

The mock now supports:

- `WhopMock.search(...)`
- routed `/payments/search`, `/invoices/search`, and `/memberships/search` endpoints

But the published `whop_sdk` surface does not currently expose first-class `search` methods analogous to `Stripe::Invoice.search`.

### 3. Lifecycle rules are modeled, not upstream-proven

The payment/invoice/membership coupling is coherent and heavily tested, but still inferred from SDK behavior and billing expectations rather than a formal upstream state machine.

### 4. Webhook union coverage is not exhaustive

We cover many useful webhook families and real unwrap flows, but not every fabricated convenience event maps to a typed SDK union model.

Concrete example:

- `payment.refunded` is fabricated and useful for testing
- the published SDK does not currently expose a typed `PaymentRefundedWebhookEvent`

### 5. No shared server-mode story

Current isolation is per session/process. There is no cross-process stateful server mode like the old `stripe-ruby-mock` server mode.

### 6. The wider published SDK surface is not covered

The current mock is intentionally strongest on billing-oriented resources. Public SDK resource families such as `affiliates`, `apps`, `chat_channels`, and `users` are not currently implemented in this repo.

## Recommended Next Hardening Order

1. Expand update/action validation breadth around the highest-traffic billing paths that remain permissive.
2. Add a small unsupported-filter/action audit against the exact list params and action methods in the published SDK.
3. Decide whether to package this as:
   - core gem only
   - core gem plus SDK-side helper shim
4. Only after that, spend time on extraction/polish work.
