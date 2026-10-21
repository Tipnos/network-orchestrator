# api service: design

How the api service meets `spec.md`. Non-normative: this document may change freely as long as the spec still holds.

## HTTP framework

The service uses **axum** on the **tokio** runtime.

- tokio is also the runtime of `async-nats`, which the `nib` crate uses, so the whole service runs on one runtime.
- axum builds on hyper and tower, so cross-cutting concerns such as timeouts and tracing use standard tower middleware.

## Checks

The checks are split across two modules, following the two stages of the spec:

- **`dto`** runs the format checks. It turns the raw HTTP request into typed values, or fails with a format error. It knows nothing about tenant rules.
- **`domain`** runs the domain checks on those typed values. It knows nothing about HTTP or JSON, so the same rules apply whatever way a tenant's intent reaches the service.

Within each module, the checks are plain functions called one after the other in the order of the spec's tables, and the first failure stops the request.

The handler does not use axum's extractors (`Json`, `Bytes`, `Path`…). They reject bad requests on their own, before the handler runs, in their own order and with plain-text bodies. That would break the check order (API-008) and the error format (API-012).

## Deployment settings

The service reads its deployment settings (API-015) with **clap**, which gives both the command-line flags and their environment variables from one definition, and generates `--help` from it.
