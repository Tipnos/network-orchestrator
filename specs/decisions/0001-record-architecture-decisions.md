# ADR-0001: Record architecture decisions

- **Status:** Accepted
- **Date:** 2026-10-16
- **Deciders:** Tristan GERMAIN
- **Supersedes:** —
- **Superseded by:** —

## Context

This project is developed agent-first: much of the code is written by coding agents working in small, independent contexts. An agent sees the specs and code for the module it works on, but not the discussions that led to them. Without a written record, agents (and new contributors) cannot tell a deliberate choice from an accident, and will reopen settled questions or quietly undo decisions while "improving" code.

Specs say what the system must do, and design docs say how a module does it. Neither records why a significant choice was made, or which alternatives were rejected.

## Decision

We will record significant architecture decisions as **Architecture Decision Records (ADRs)** in `specs/decisions/`, using the format of this file.

**When to write an ADR.** A decision needs an ADR if it is hard to reverse or affects more than one module. Examples: choosing a storage or messaging technology, a cross-service protocol, a concurrency model, a project-wide policy. Choices confined to one module's internals belong in its `design.md` instead.

**Numbering and naming.** Files are named `NNNN-short-slug.md`, with a four-digit, zero-padded sequence number. Numbers are assigned in order of creation and never reused. The number is the ADR's permanent identifier (`ADR-0002`); the slug is only for readability.

**Statuses.**

- **Proposed**: under discussion; not yet binding.
- **Accepted**: binding. All code and specs must comply.
- **Rejected**: considered and declined; kept for the record.
- **Superseded**: replaced by a later ADR, named in its header.

**Immutability.** Once an ADR is accepted, its content is never edited, apart from the status line and the "Superseded by" field. To change a decision, write a new ADR that supersedes the old one and explains what changed. Correcting typos and broken links is allowed.

**Structure.** Every ADR has these sections:

1. **Context**: the problem and the forces at play.
2. **Decision**: what we chose, stated in active voice ("We will…").
3. **Alternatives considered**: the options rejected, with the reason for each.
4. **Consequences**: what becomes easier and harder, accepted risks, and follow-up work.

## Alternatives considered

- **Record decisions in specs or design docs**: mixes "why" into documents meant to state "what" and "how", and the reasoning gets lost when those documents are rewritten.
- **Rely on pull request and issue history**: the reasoning exists but is scattered, hard to find, and outside the context agents are given.
- **No formal record**: lowest effort, but leaves agents with no way to recognize settled decisions.

## Consequences

**Positive**

- Agents and contributors can see why the system is the way it is, and which questions are already settled.
- Decision history is versioned with the code and reviewed in the same pull requests.
- Superseding ADRs keep a readable trail of how the architecture evolved.

**Negative**

- Writing ADRs takes time, and the "significant decision" threshold needs judgment.
- The `decisions/` folder only helps if agents are told to read it; the root `AGENTS.md` must point to it.

**Follow-ups**

- Add the rules for agents above to the root `AGENTS.md`.
- Add an index of ADRs (number, title, status) to `specs/README.md`.
