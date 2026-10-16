# ADR-0002: Use NATS JetStream as the substrate for the NIB and inter-service messaging

- **Status:** Accepted
- **Date:** 2026-10-16
- **Deciders:** Tristan GERMAIN
- **Supersedes:** —
- **Superseded by:** —

## Context

All microservices share a common state store, the NIB (Resource Information Base), in the spirit of the Orion SDN control plane. Services read and write NIB tables and react to changes in them, so the substrate must provide:

- durable, replicated key-value storage for NIB tables
- change notifications (watch) that a service can resume from a known revision after a restart
- optimistic concurrency (compare-and-set on a revision) so concurrent writers cannot silently overwrite each other
- per-service access control, to enforce single-writer ownership of NIB key prefixes
- pub/sub messaging for service-to-service events that are not NIB state
- a maintained, async Rust client

Operating several infrastructure systems (a database, a message broker, a cache) is a significant cost for a small team, so one substrate covering both state and messaging is strongly preferred.

## Decision

We will use **NATS with JetStream** as the single substrate for:

1. **NIB storage**: each NIB table maps to a JetStream KV bucket. Watches use KV watchers; concurrent updates use revision-based compare-and-set.
2. **Inter-service messaging**: core NATS subjects for fire-and-forget events, JetStream streams where delivery must be durable.

Services never use NATS directly for NIB access. All NIB access goes through the `NIB` library crate, which is the only code that knows the NIB is backed by NATS (see `specs/constitution.md`). The Rust client is `async-nats`.

Ownership of NIB key prefixes is enforced by NATS account and user permissions, in addition to checks in the `NIB` crate.

## Alternatives considered

- **etcd**: strong consistency and mature watch semantics, and a natural fit for control-plane state. Rejected because it does not cover messaging, so we would still need a broker. It is also designed for small datasets, which may limit NIB growth.
- **Kafka + a separate KV store**: excellent durable log, but two systems to operate, heavy for our scale, and Kafka alone is a poor fit for keyed lookups.
- **Redis (with Streams)**: simple and fast, but persistence and replication guarantees are weaker than we need for the NIB, and its access control is coarser.
- **PostgreSQL + LISTEN/NOTIFY**: strong consistency and a familiar tool, but notifications are not durable or replayable, and it becomes a central bottleneck for event traffic.

## Consequences

**Positive**

- One system to deploy, monitor and secure for both state and messaging.
- Watch-from-revision lets services rebuild their in-memory view after a restart without a separate snapshot mechanism.
- Subject-based permissions give us a native way to enforce NIB ownership.
- The `NIB` crate isolates the choice: replacing NATS later affects one crate and its design doc, not the services.

**Negative / risks**

- JetStream KV has no multi-key transactions. Any NIB invariant spanning several keys must be designed around this (single-key aggregates, or one owner per invariant). This constraint must be stated in `specs/interfaces/nib.md`.
- Read consistency depends on configuration (reads served by the stream leader versus direct gets from replicas). The guarantees we promise in the NIB interface must match the bucket settings chosen in `crates/nib/spec/design.md`.
- The team needs JetStream operational knowledge: clustering, replica counts, retention and storage limits.
- We depend on the maturity of `async-nats` for the JetStream KV API.

**Follow-ups**

- Write `specs/interfaces/nib.md`: data model, consistency guarantees, watch semantics, ownership rules.
- Write `crates/nib/spec/design.md`: bucket layout, replica count, history depth, subject naming.
- Consider a TLA+ model of watch-and-resume and compare-and-set behavior under leader failover.
