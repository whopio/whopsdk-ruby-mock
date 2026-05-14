# Changelog

## [0.1.0] - 2026-05-04

### Added

- Real `WhopSDK::Client` integration coverage across billing and webhook surface
- Schema-driven in-memory CRUD, filtering, cursor pagination, and relation hydration
- Lifecycle-aware billing side effects for payments, invoices, memberships, and refunds
- Webhook fabrication, retrieval, signing, and real SDK unwrap coverage
- Payment token helpers and `stripe-ruby-mock`-style test helper ergonomics
- Adversarial stress coverage for create-heavy billing and refund loops
- Create/update/action/list validation for highest-risk billing paths with real SDK error classes

## Unreleased

_No unreleased changes._
