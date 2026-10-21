# ADR-0003: Encode messages with MessagePack and describe them with JSON Schema generated from Rust types

- **Status:** Accepted
- **Date:** 2026-10-16
- **Deciders:** Tristan GERMAIN
- **Supersedes:** —
- **Superseded by:** —

## Context

Services exchange data in two ways: values stored in the NIB (ADR-0002) and event messages sent over NATS. Each service is owned by one team, and that team owns the schema of the NIB tables it writes and the events it emits. Schemas evolve with the owner's needs and its clients' constraints, so we need:

- a compact binary encoding for values and messages
- a readable, language-neutral description of every schema, which clients can review
- schema evolution without breaking existing readers: adding fields must be safe
- a way to detect breaking changes automatically, before they are merged
- little tooling: no separate interface language, no code-generation step

All services are written in Rust and live in one Cargo workspace.

## Decision

**Encoding.** Values and messages are encoded as **MessagePack** using `rmp-serde`. All encoding and decoding goes through a single codec module provided by the `nib` crate; services never call `rmp-serde` directly.

**Structs are encoded as maps.** The codec uses `rmp_serde::to_vec_named`, which writes field names as map keys. Positional array encoding (`rmp_serde::to_vec`) is forbidden: with it, adding or reordering a field silently corrupts every reader.

**Source of truth.** The schema of a value or message is the Rust type that defines it, in the owning service's `types` crate. Every such type derives `Serialize`, `Deserialize` and `JsonSchema` (from `schemars`).

**JSON Schema files.** A JSON Schema is generated from each type and committed under `crates/<service>/types/schema/`, named by type and major version (`link.v1.json`). These files are generated, never edited by hand. They are the readable contract that client teams review.

**Data model rules.** So that the JSON Schema accurately describes what MessagePack carries:

- map keys are strings only;
- no MessagePack extension types and no raw binary; binary data, if ever needed, is a base64 string;
- enums use one representation project-wide: internally tagged, `#[serde(tag = "type")]`;
- types never use `#[serde(deny_unknown_fields)]`: readers ignore fields they do not know;
- fields added after a type's first release are optional, with `#[serde(default)]`.

**Versioning.** Each major version of a schema lives in its own module of the `types` crate (`v1`, `v2`), side by side. During a migration the owner writes both versions until no client reads the old one.

**Compatibility check.** A CI step, `cargo xtask schema-check`, regenerates every schema and compares it with the committed file:

- adding an optional field passes;
- removing or renaming a field, changing a field's type, adding a required field or removing an enum variant fails, unless it happens in a new major version module.

## Alternatives considered

- **Protocol Buffers (`prost`)**: field numbers make evolution safe by construction, and `buf breaking` checks compatibility for free. Rejected for its separate interface language, code-generation step and less natural Rust types, which add tooling cost the project does not need while every service is in Rust.
- **JSON only**: human-readable and directly described by JSON Schema. Rejected as the default for size and parsing cost, but remains a fallback: the codec is in one crate, so switching is a one-crate change plus a data migration.
- **bincode / postcard**: very compact and fast, but positional and Rust-specific, with no schema a client team could review. Field changes break readers silently.
- **CBOR (`ciborium`)**: technically equivalent to MessagePack for our needs. MessagePack was preferred for its wider familiarity and tooling; this choice could be revisited at low cost.
- **Apache Avro**: strong schema evolution rules, but schemas are written separately from the Rust types and the Rust tooling is less mature.

## Consequences

**Positive**

- One definition per schema, in plain Rust; no interface language or generated code to maintain.
- Client teams review a readable JSON Schema in pull requests, without reading Rust.
- Map encoding plus the data model rules make additive changes safe for existing readers.
- The schema check makes the compatibility rules enforceable instead of a review convention.

**Negative / risks**

- Values in NATS are not human-readable; inspecting them needs a decoding tool. A small `xtask` or `nib` CLI command to decode a key is worth adding early.
- Map encoding repeats field names in every value, costing some size compared with positional formats.
- The compatibility check is ours to write and maintain, and its rules must stay in sync with this ADR.
- The data model rules exclude some valid serde patterns (non-string map keys, untagged enums); a reviewer or agent must catch violations until a lint does.

**Follow-ups**

- Implement the codec in the `nib` crate, with a test proving that adding an optional field keeps old readers working.
- Implement `cargo xtask schema-check`.
- Add the data model rules to `specs/constitution.md`.
- Record the service-owned `types` crate model and side-by-side versioning in its own ADR.
