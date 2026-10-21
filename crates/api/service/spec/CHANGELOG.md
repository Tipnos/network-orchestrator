# Changelog: api service spec

All changes to `spec.md`. Versions follow the rules in `specs/README.md`: major when a requirement changes or is removed, minor when one is added, patch for wording only.

## 0.1.0

First draft.

- `PUT /v1/tenants/{name}`: creates a tenant or replaces its intent; idempotent; answers `202 Accepted` with the recorded intent (API-001 to API-011). Format checks (API-001 to API-005) run before domain checks (API-006, API-007).
- Common rules: RFC 9457 error responses (API-012 to API-014); deployment settings for the maximum number of servers and the maximum body size, with their flags, environment variables and defaults (API-015).
