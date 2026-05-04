# Changelog

## Unreleased

- Added real `WhopSDK::Client` integration coverage across the currently exposed billing and webhook surface.
- Added schema-driven in-memory CRUD, filtering, cursor pagination, and relation hydration.
- Added lifecycle-aware billing side effects for payments, invoices, memberships, and refunds.
- Added webhook fabrication, retrieval, signing, and real SDK unwrap coverage.
- Added payment token helpers and `stripe-ruby-mock`-style test helper ergonomics.
- Added adversarial stress coverage for create-heavy billing and refund loops.
- Added create/update/action/list validation for the highest-risk billing paths with real SDK error classes.
