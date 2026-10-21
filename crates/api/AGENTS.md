# AGENTS.md: api service

Instructions specific to the api service. The root `AGENTS.md` still applies; where the two disagree for this service, this file wins.

## Role

The public HTTP entry point of the system. Clients use it to declare the intent of their tenants.

## Read first

1. `service/spec/spec.md`: what the service must do. Normative.
2. `service/spec/design.md`: how it does it. Non-normative.
3. `specs/glossary.md` and `specs/constitution.md` (once it exists).

The service depends on no other service's `types` crate yet.

## Current scope

Only `PUT /v1/tenants/{name}` is specified. These are deliberately **not** specified yet:

- how the intent is stored (NIB table, revision, ETag);
- tenant status and convergence;
- conditional requests (`If-Match`, `If-None-Match`);
- every other endpoint (GET, DELETE, listing).

Do not implement them, and do not invent behavior for them. If a task needs one, stop and ask for the spec to be written first.

Because storage is not specified, the PUT can be implemented only up to its checks:

- Implement the checks (API-001 to API-009), the error responses (API-012 to API-014) and the deployment settings (API-015).
- Do not implement the success path (API-010, API-011). Until storage is specified, a request that passes every check gets `501 Not Implemented`, as a problem+json body with `type` `about:blank`. This is temporary and not part of the spec.

## Conventions

- The order of the checks table in `spec.md` is normative: the first failing check decides the response.
- Test names start with the requirement ID they check, in lowercase: `fn api_007_rejects_servers_above_max()`.
- Error `type` values are part of the contract (API-014); never rename one.

## Commands

```sh
cargo build -p api
cargo test -p api
cargo clippy -p api --all-targets -- -D warnings
```
