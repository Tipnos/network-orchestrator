# Glossary

Shared vocabulary for all specs, design docs and ADRs in this repository.

**Rules**

- Specs use these terms exactly as defined here and do not redefine them. If a spec needs a new term, add it here first.
- One entry per term, in alphabetical order. Acronyms are listed under the acronym, with the expansion in parentheses.
- Keep each definition to a few sentences and link to the spec that owns the details.

---

**ADR (Architecture Decision Record)**: A short, numbered document in `specs/decisions/` that records one significant decision: its context, the choice made and its consequences. Once accepted, an ADR is never edited; a later ADR may supersede it.

**Types crate**: The crate `crates/<service>/types`, named `<service>-types`, which holds a service's published contract: the Rust types of the NIB values it writes and the events it emits, the generated JSON Schemas, and its types spec. Owned by the service's team. Other services may depend on it.

**Types spec**: The normative `types/spec/types.md` of a service, describing what it promises its clients: the NIB tables it owns, the events it emits and the guarantees attached to them. Versioned with semver.

**Breaking change**: A change to a type that can make an existing client fail, such as removing or renaming a field, changing a field's type, adding a required field or removing an enum variant. Only allowed in a new major version. See ADR-0003.

**Codec**: The single module in the `nib` crate that encodes and decodes values and messages as MessagePack. No other code encodes or decodes directly. See ADR-0003.

**Constitution**: The project-wide rules every service and crate must follow, such as the error-handling policy, MSRV and `unsafe` policy. See `specs/constitution.md`.

**Design doc**: A `design.md` file describing how a module implements its spec: types, traits, algorithms, data layout. Non-normative; it may change as long as the spec still holds.

**Interface spec**: A spec in `specs/interfaces/` describing a contract no single team owns, such as the NIB's general semantics. Changes to it affect every service.

**JSON Schema**: The readable description of a value or message type, generated from its Rust type and committed under `types/schema/`. Never edited by hand. See ADR-0003.

**NIB (Network Information Base)**: The shared, replicated state store that all services read from and react to, after the NIB of Google's Orion SDN control plane. It is organized into tables. Each table has exactly one owning service that may write to it; any service may read or watch it. Services access it only through the `nib` crate. See `specs/interfaces/nib.md`.

**Owner (of a NIB table)**: The single service allowed to write to a NIB table. It declares the table in its types spec and defines the table's value types in its types crate. Ownership is enforced by the `nib` crate and NATS permissions.

**Owning team**: The team responsible for a service, listed in `CODEOWNERS`. It decides how the service and its types evolve, taking its clients' constraints into account.

**Requirement ID**: A stable identifier for one requirement in a spec, such as `NIB-010`. Tests reference it so every requirement can be traced to the code that checks it. IDs are never reused.

**Service crate**: The crate `crates/<service>/service`, holding a service's implementation and its service spec and design doc. Private to the owning team; no other service may depend on it.

**Spec**: A normative document stating what must hold, as seen from outside a module: behavior, invariants, error model and limits. Service specs, types specs and interface specs are all specs. Versioned with semver.
