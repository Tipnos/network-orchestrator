---
id: api
version: 0.1.0
status: draft
owner: api-team
depends_on: []
---

# api service

The api service is the public HTTP entry point of the system. Clients use it to declare the intent of their tenants.

This spec has one section per endpoint. Each section gives the endpoint's purpose, its request, the checks applied to it in order, and its success response. Rules shared by several endpoints are under "Common rules" at the end.

## PUT /v1/tenants/{name}

Creates a tenant, or replaces the intent of an existing one. The request carries the whole intent. The service records it and answers before the network has converged to it.

The request is idempotent: sending it several times has the same effect as sending it once. A client that gets no answer, for example after a timeout, can safely send it again.

### Request

| Part | Value |
|---|---|
| Path parameter `name` | The tenant's name, chosen by the client. Its format is given under "Checks". |
| Header `Content-Type` | `application/json` |
| Body | A JSON object with the fields below. |

Body fields:

| Field | Type | Required | Meaning |
|---|---|---|---|
| `servers` | integer | yes | The number of servers the tenant connects. |

The body has no other fields.

Example:

```http
PUT /v1/tenants/acme HTTP/1.1
Content-Type: application/json

{ "servers": 8 }
```

### Checks

The service checks each request in two stages, in this order:

1. **Format checks** look at the HTTP request itself: its headers and the shape of its body. They turn the request into typed values.
2. **Domain checks** look at those values and apply the rules of a tenant.

The error body is described under "Common rules"; the last column gives its `type`.

#### Format checks

| ID | The service MUST reject the request when… | Status | Error `type` |
|---|---|---|---|
| API-001 | the `Content-Type` header is missing, or its media type is not `application/json`. | 415 | `urn:sdn:api:unsupported-media-type` |
| API-002 | the body is larger than the maximum body size. | 413 | `urn:sdn:api:body-too-large` |
| API-003 | the body is not a valid JSON object. A field that appears more than once is not an error: its last occurrence is used. | 400 | `urn:sdn:api:malformed-body` |
| API-004 | the body has one or more fields not listed under "Request". The error names all of them. | 422 | `urn:sdn:api:unknown-field` |
| API-005 | `servers` is missing, or is not a JSON integer: a number written with a fraction or an exponent, such as `8.0` or `8e0`, is not an integer, and neither is an integer too large to fit in 64 bits. The error names `servers`. | 422 | `urn:sdn:api:invalid-field` |

#### Domain checks

| ID | The service MUST reject the request when… | Status | Error `type` |
|---|---|---|---|
| API-006 | `name` is not an RFC 1123 DNS label: 1 to 63 characters, only lowercase `a`–`z`, digits and `-`, starting and ending with a letter or a digit. The service MUST NOT change the case of `name` to make it valid. | 400 | `urn:sdn:api:invalid-name` |
| API-007 | `servers` is less than 1 or greater than the maximum number of servers. The error names `servers`. | 422 | `urn:sdn:api:servers-out-of-range` |

- **API-008**: The service MUST apply every format check before any domain check, and the checks of each stage in the order of its table. It MUST respond with the error of the first check that fails.
- **API-009**: A rejected request MUST NOT change the intent of any tenant.

### Success

- **API-010**: When a request passes every check, the service MUST record the request's body as the tenant's whole intent, creating the tenant if it does not exist. It MUST then respond `202 Accepted` with `Content-Type: application/json` and a body holding the tenant's `name` and the recorded `servers`.
- **API-011**: The response MUST be the same whether the request created the tenant, changed its intent or repeated its current intent. When the tenant's intent already equals the request's body, the request MUST leave it unchanged.

Example:

```http
HTTP/1.1 202 Accepted
Content-Type: application/json

{ "name": "acme", "servers": 8 }
```

> **Why 202 and not 201 (informative).** RFC 9110 asks for `201 Created` when a PUT creates a resource. This service answers `202 Accepted` in every case on purpose:
> - the client gets one answer for create, update and retry, so a retry after a lost response looks exactly like the first attempt;
> - 202 says the work is not finished: the intent is recorded, but the network has not converged to it yet.

## Common rules

### Error responses

- **API-012**: Every error response MUST have `Content-Type: application/problem+json` and a body in the format of RFC 9457, with these fields:

  | Field | Value |
  |---|---|
  | `type` | The error's `type`, as given by the check that failed. |
  | `title` | A short, human-readable summary of the error `type`. It is the same for every error of that `type`. |
  | `status` | The HTTP status code of the response. |
  | `detail` | A human-readable explanation specific to this request. |

- **API-013**: When the error concerns fields of the body, the body MUST also have an `errors` member: an array with one object per field at fault, even when there is only one. Each object has:
  - `pointer`: a JSON Pointer (RFC 6901) to the field, in URI fragment form, such as `#/servers`;
  - `detail`: a human-readable explanation of what is wrong with that field.
- **API-014**: An error's `type` is part of the contract: once published, it MUST keep its meaning. The wording of `title` and of every `detail`, including those inside `errors`, is not part of the contract and MAY change without a new spec version.

Example:

```http
HTTP/1.1 422 Unprocessable Content
Content-Type: application/problem+json

{
  "type": "urn:sdn:api:servers-out-of-range",
  "title": "servers out of range",
  "status": 422,
  "detail": "servers must be between 1 and 64, got 65",
  "errors": [
    { "pointer": "#/servers", "detail": "must be between 1 and 64" }
  ]
}
```

### Deployment settings

Some limits are chosen by whoever deploys the service. Each one can be set with a command-line flag or an environment variable, and has a default.

| Setting | Flag | Environment variable | Default | Used by | Meaning |
|---|---|---|---|---|---|
| Maximum number of servers | `--max-servers` | `API_MAX_SERVERS` | 64 | API-007 | The largest `servers` value a tenant's intent may hold. |
| Maximum body size | `--max-body-bytes` | `API_MAX_BODY_BYTES` | 4096 | API-002 | The largest request body, in bytes, the service accepts. |

- **API-015**: The service MUST read each setting above from its flag or, when the flag is absent, from its environment variable. When neither is given, it MUST use the default. A setting MUST apply in the same way to every tenant.
