# AGENTS.md

Instructions for coding agents working in this repository. Read this file first. Each service has its own `AGENTS.md`; when you work inside a service, read it too. The nearest one takes precedence for that service.

## Project

An educational software-defined networking (SDN) controller, inspired by Google's Orion. Clients declare the desired state of the network through a public API, and the system turns that intent into per-device configuration and programs the equipment until what the network actually does converges to it.

A Rust workspace of independent microservices, each owned by one team. Services share state through the **NIB** (Network Information Base), a store backed by NATS JetStream and accessed only through the `nib` crate. See `specs/glossary.md` for all project terms.

## Repository layout

```
AGENTS.md                  # this file
CODEOWNERS                 # which team owns which service
specs/
  README.md                # index of all specs and ADRs, with status and version
  constitution.md          # project-wide rules; always applies
  glossary.md              # shared vocabulary; always applies
  interfaces/              # contracts no single team owns
    nib.md                 # NIB semantics: consistency, watch, ownership rules
  decisions/               # ADRs (Architecture Decision Records)
docs/                      # human-facing explanations; never authoritative
crates/
  nib/                     # NIB client and shared codec; the only code that talks to NATS
  <service>/
    AGENTS.md              # service-specific instructions
    types/                   # crate `<service>-types`: the service's published contract
      spec/
        types.md             # tables it owns, events it emits, guarantees to clients
        CHANGELOG.md
      schema/              # JSON Schemas generated from the types; never edit by hand
      src/
        v1/                # types for major version 1 (v2/ alongside during a migration)
    service/               # crate `<service>`: the implementation
      spec/
        spec.md            # what the service must do
        design.md          # how it does it
        CHANGELOG.md
      src/
xtask/                     # repository tooling: spec-check, schema-check
```

## What to read before a task

Load only what the task needs:

1. Always: `specs/constitution.md` and `specs/glossary.md`.
2. The service you are changing: its `AGENTS.md`, its `types/spec/` and its `service/spec/`.
3. For each service yours depends on: its `types/spec/types.md` only.
4. Every file in `specs/interfaces/` that your specs reference.
5. Any ADR in `specs/decisions/` that covers what you are changing (check the index in `specs/README.md`).

Never read another service's `service/` folder (implementation, spec or design) to understand your task. If you think you need to, see "Service independence" below.

## Specs, design docs and ADRs

Each kind of document has one job:

- **Types spec** (`types/spec/types.md`): what a service promises its clients. Normative.
- **Service spec** (`service/spec/spec.md`): what the service must do, as seen from outside it. Normative.
- **Interface spec** (`specs/interfaces/*.md`): contracts no single team owns, such as the NIB's semantics. Normative.
- **Design doc** (`design.md`): how a module meets its spec. Non-normative; may change freely while the spec still holds.
- **ADR** (`specs/decisions/NNNN-*.md`): why a significant decision was made.
- **docs/**: explanations for humans. Never treat them as requirements; if they contradict a spec, the spec wins.

To decide where something belongs: if changing it could break a caller, a user or another service, it is spec. If only the module's internals would notice, it is design.

### Spec rules

- **Spec first.** A change to observable behavior updates the spec in the same pull request, before or alongside the code. Code that disagrees with its spec is a bug in one of the two; say which, do not silently pick one.
- **Requirement IDs.** Every requirement has a stable ID (`NIB-010`, `TOPOLOGY-TYPES-004`) and uses MUST / SHOULD / MAY in the RFC 2119 sense. IDs are never reused or renumbered.
- **Traceability.** Every test that checks a requirement references its ID, in the test name (`fn nib_010_rejects_foreign_writer`) or a comment (`// spec: NIB-010`). New requirements need at least one test.
- **Versioning.** Each spec has a semver `version` in its frontmatter and an entry in its `CHANGELOG.md` for every change:
  - major: a requirement changed or was removed;
  - minor: a requirement was added;
  - patch: wording or clarification only.
- **Size.** Keep a spec around 200–400 lines. If it grows well beyond that, propose splitting the module.
- **Vocabulary.** Use terms exactly as defined in `specs/glossary.md`. Add a new term there before using it in a spec.

### ADR rules

- Before changing anything an accepted ADR covers, read that ADR. Do not contradict it in code or specs.
- Never edit an accepted ADR, except its status line and "Superseded by" field.
- If a task seems to require breaking an accepted ADR, stop and say so. Do not work around it. Propose a new ADR that supersedes it.
- When a change introduces a decision that is hard to reverse or affects more than one module, draft an ADR with status **Proposed** in the same pull request. Full rules: `specs/decisions/0001-record-architecture-decisions.md`.

## Service independence

- Each service is owned by one team, listed in `CODEOWNERS`. Its `types` crate is its published contract; its `service` crate is private to the team.
- A service may depend on another service's `types` crate and reference its `types.md`. It must never depend on, reference or read another service's `service` crate, spec or design.
- If your task needs something another service does not publish, do not reach into its internals. Stop and propose a change to that service's Types, to be agreed with its owning team.
- Do not modify another team's service. If a change there is needed, describe it instead.

## Types and schemas

Rules from ADR-0003:

- The Rust types in a service's `types` crate are the source of truth for its NIB values and events. They derive `Serialize`, `Deserialize` and `JsonSchema`.
- JSON Schemas in `types/schema/` are generated. Never edit them by hand; regenerate them with the `xtask`.
- Encode and decode only through the codec in the `nib` crate. Never call `rmp-serde` directly.
- Data model rules: string map keys only; no binary or MessagePack extension types; enums use `#[serde(tag = "type")]`; never use `#[serde(deny_unknown_fields)]`; fields added after a type's first release use `#[serde(default)]`.
- **Allowed in a minor version:** adding an optional field, adding a new type, adding a new table or event.
- **Breaking, requires a new major version module** (`v2/` next to `v1/`): removing or renaming a field, changing a field's type, adding a required field, removing an enum variant, changing the meaning of a field.
- During a migration the owning service writes both versions. Remove the old version only when no client depends on it.
- If you change your service's `types` crate, list the services that depend on it in the pull request description.

## NIB rules

- Access the NIB only through the `nib` crate. Never use NATS subjects, KV buckets or streams directly for NIB data.
- Each NIB table has exactly one owning service, which declares it in its `types.md` and defines its value types in its `types` crate. A service writes only to the tables it owns; it may read or watch any table.
- The NIB has no multi-key transactions. Do not write code that assumes several keys change atomically.
- NATS-specific details (bucket layout, subjects, replica settings) belong in `crates/nib/` design docs, never in a service or types spec.

## Build and test

```sh
cargo build --workspace
cargo test --workspace
cargo clippy --workspace --all-targets -- -D warnings
cargo fmt --all -- --check
cargo xtask schema-check     # schemas regenerate cleanly and changes are compatible (when added)
cargo xtask spec-check       # requirement ↔ test traceability (when added)
```

<Add here how to run a local NATS server for integration tests.>

Where a requirement is a property or invariant, prefer a checking tool over example tests: `proptest` for properties, `loom` for concurrency invariants, `kani` for bounded model checking.

## Before you finish

- [ ] Build, tests, clippy, fmt and the `xtask` checks pass.
- [ ] Observable behavior changes are reflected in the spec, with a version bump and changelog entry.
- [ ] New or changed requirements have tests that reference their IDs.
- [ ] API changes are compatible, or live in a new major version module; schemas are regenerated.
- [ ] No accepted ADR is contradicted; any new significant decision has a Proposed ADR.
- [ ] No service depends on another service's `service` crate, spec or design.
- [ ] The pull request description says which spec and types versions changed and which services are affected.
