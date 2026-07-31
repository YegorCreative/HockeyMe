# Architecture Decisions

## ADR-001 — Supabase RLS is the authorization boundary

Status: accepted.

Clients may hide unauthorized actions for usability, but UI routing and role
checks are never considered authorization. Every protected operation must be
enforced by RLS or a narrowly granted server function.

## ADR-002 — Environment selection is compile-time constrained

Status: accepted.

Debug, Staging, and Production use separate configuration resources. Debug and
Staging reject the production project host. Missing non-Debug configuration
fails closed. Credentials are not committed.

## ADR-003 — Developer Mode is Debug-only and in-memory

Status: accepted.

Developer Mode uses production-shaped models and repositories but performs no
authentication, networking, credential loading, or persistence. Its
implementation is enclosed by `#if DEBUG` and cannot compile into Staging or
Release.

## ADR-004 — Offline storage is actor-isolated

Status: accepted with follow-up.

`OfflineStore` serializes filesystem access, uses atomic protected writes, and
isolates user files by UUID. Workout and testing queues use stable identifiers
for idempotency.

Follow-up: add cache freshness metadata and an explicit sign-out disposition
policy.

## ADR-005 — Synchronization passes are coalesced

Status: accepted.

Reconnect and manual operations may request synchronization concurrently.
`SynchronizationGate` permits one active pass and makes concurrent callers
await the same result. Connectivity callbacks fire on an actual transition to
online. This prevents duplicate network work and pending-queue rewrite races.

## ADR-006 — Errors use presentation categories

Status: accepted.

`AppErrorPresentation` maps network, timeout, authentication, validation,
permission, missing-data, repository, cancellation, and unexpected errors to
privacy-safe explanations and recovery behavior. Cancellation does not produce
an error alert.

## ADR-007 — Native presentation remains platform-specific

Status: accepted.

iPhone uses compact athlete workflows. Mac uses native split views, tables,
inspectors, commands, and keyboard navigation. Models and Design System tokens
are shared where platform-neutral; platform presentation is not forced into a
single abstraction.

## ADR-008 — Repository protocols are the future integration seam

Status: proposed.

Existing concrete repositories made early delivery direct but now limit unit
isolation and Mac reuse. Introduce narrow feature protocols without a
repository-wide rewrite. Preserve current method semantics and add adapters
incrementally.

## ADR-009 — Performance changes require evidence

Status: accepted.

Use Instruments, signposts, query counts, and representative fixture sizes.
Retain lazy containers and native controls. Do not add caches, denormalization,
or custom rendering solely from speculation.

## ADR-010 — Schema changes require explicit migration review

Status: accepted.

Client hardening does not silently alter database schemas. Any concurrency
versioning or aggregate RPC requires a migration, RLS review, rollback plan,
and backward-compatibility assessment.
