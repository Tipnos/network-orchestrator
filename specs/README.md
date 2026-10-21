# Specs

This folder holds the normative documents of the project: what the system must do, the contracts between services, and the decisions behind them. Explanations for humans live in `docs/` and are never authoritative.

Agents and contributors start from the root `AGENTS.md`, which says which of these documents to load for a given task. This file is the index: every spec and ADR is listed here with its status and version.

**Keep this index current.** A pull request that adds a spec or ADR, or changes the version or status of one, updates this file in the same pull request.

## Where documents live

| Kind | Location | Owned by |
|---|---|---|
| Constitution | `specs/constitution.md` | everyone |
| Glossary | `specs/glossary.md` | everyone |
| Interface specs | `specs/interfaces/*.md` | everyone; no single team |
| ADRs | `specs/decisions/NNNN-*.md` | everyone |
| Types spec of a service | `crates/<service>/types/spec/types.md` | the service's team |
| Service spec | `crates/<service>/service/spec/spec.md` | the service's team |
| Design doc | `crates/<service>/service/spec/design.md` | the service's team |

Service, Types and design documents live next to their code so that each team owns them and each service's context stays self-contained. They are still listed below.

## Conventions

### Spec frontmatter

Every spec starts with:

```yaml
---
id: topology-types        # unique, kebab-case; prefix for requirement IDs (TOPOLOGY-TYPES-001)
version: 1.0.0            # semver, see below
status: draft             # draft | review | stable | deprecated
owner: <team>             # or "shared" for documents in specs/
depends_on:               # other specs this one relies on, with version ranges
  - interfaces/nib@^1
---
```

### Spec status

- **draft**: being written; not binding.
- **review**: complete and under review; not yet binding.
- **stable**: binding. Code must comply.
- **deprecated**: being phased out; names its replacement.

### Spec versions

- **major**: a requirement changed or was removed.
- **minor**: a requirement was added.
- **patch**: wording or clarification only.

Every version change has an entry in the spec's `CHANGELOG.md`.

### ADR status

**Proposed**, **Accepted**, **Rejected** or **Superseded**. Accepted ADRs are never edited, apart from their status line. See ADR-0001.

## Index

### Project-wide

| Document | Status | Version |
|---|---|---|
| [Constitution](constitution.md) | draft | 0.1.0 |
| [Glossary](glossary.md) | draft | 0.1.0 |

### Interface specs

| Spec | Scope | Status | Version |
|---|---|---|---|
| [NIB](interfaces/nib.md) | NIB semantics: data model, consistency, watch, ownership rules | draft | 0.1.0 |

### Services

| Service | Team | Types spec | Service spec | Status |
|---|---|---|---|---|
| _none yet_ | | | | |

<!-- Example row:
| topology | <team> | [types.md](../crates/topology/types/spec/types.md) v1.2.0 | [spec.md](../crates/topology/service/spec/spec.md) v1.0.3 | stable |
-->

### Shared crates

| Crate | Spec | Design | Status | Version |
|---|---|---|---|---|
| `nib` | [spec.md](../crates/nib/spec/spec.md) | [design.md](../crates/nib/spec/design.md) | draft | 0.1.0 |

### Architecture decisions

| ADR | Title | Status |
|---|---|---|
| [0001](decisions/0001-record-architecture-decisions.md) | Record architecture decisions | Accepted |
| [0002](decisions/0002-nats-substrate.md) | Use NATS JetStream as the substrate for the NIB and inter-service messaging | Accepted |
| [0003](decisions/0003-messagepack-json-schema.md) | Encode messages with MessagePack and describe them with JSON Schema generated from Rust types | Accepted |
