# ADR: Dep–Proof placement in the repository estate

**Decision:** the canonical home of Dep–Proof is `larsbx/crypto-composer`. Generic proof/evidence record infrastructure remains in `larsbx/finite-math-kernels/proof_records/`. No new top-level repository is introduced.

**Status:** architecture decision and implementation map.

## Context

The Dep–Proof design introduces a scheme-indexed dependency DSL and semantics, deterministic normalization, structured residual proof planning, an obligation-graph interpreter, and certificate construction.

The estate already contains two complementary pieces:

1. `crypto-composer` owns cryptographic composition semantics and validation.
2. `finite-math-kernels/proof_records` owns reusable content-addressed evidence records, dependency closure, canonical identity, and relationship-graph projection.

Putting Dep–Proof into a third repository would split the semantic owner from the composition/checker code it is meant to organize, while duplicating evidence machinery already consolidated in `finite-math-kernels`.

## Current crypto-composer anchors

The existing code already supplies most of the domain-side inputs Dep–Proof requires.

| Dep–Proof responsibility | Existing location | Current role |
| --- | --- | --- |
| Primitive/interface contracts | `src/types/contracts.zig` | KEM/KDF/AEAD/SIG contracts and product requirements |
| Assumptions | `src/types/assumptions.zig` | named assumption classes/expressions |
| Concrete construction state | `src/schemas/graph.zig` | `CompositionGraph`, values, operations, flows, outputs |
| Checkable local constraints | `src/constraints/` | C1–C6 and warnings |
| Constraint dispatcher | `src/constraints/checker.zig` | present checker surface |
| Proof-associated regression tests | `test/harness.zig` | statement/argument/evidence metadata tied to tests |
| Artifact emission | `src/emit/artifact.zig` | current graph summary; already notes future machine-readable security claims and structured reductions |
| Red/green execution provenance | `tdd_ledger.zig` | test execution ledger |

What does **not** yet exist as a unified subsystem is the DepSpec/Sat/WF/NF0/VCPlan/RunPlan layer specified in `docs/DEP_PROOF_SPEC.md`.

## Decision

### Canonical semantic owner: crypto-composer

`crypto-composer` owns:

- `DepSpec` syntax;
- scheme-indexed `Sat(S,D)`;
- well-formedness;
- P0/P1 normalization;
- VC generation;
- `Prop/CProp` distinction;
- `VCPlan`;
- `VCGraph` and control gates;
- `RunPlan`;
- crypto-domain GAME/OBS/WIT/RED objects;
- verifier adapters;
- certificate semantics;
- explicit TCB and security-model declarations.

This is the right ownership boundary because these concepts interpret cryptographic constructions and their security/implementation contracts.

### Shared evidence substrate: finite-math-kernels

`finite-math-kernels/proof_records` continues to own only generic evidence infrastructure:

- record identity;
- canonical serialization;
- evidence classification;
- identity-bearing dependency edges;
- dependency closure;
- typed relationship-graph projection;
- evidence-vocabulary translation.

The package explicitly does not prove statements or supply consumer policy. Dep–Proof must preserve that boundary.

## Intended physical layout

```text
crypto-composer/
  docs/
    DEP_PROOF_SPEC.md
    DEP_PROOF_ESTATE_PLACEMENT.md

  src/
    dep/
      ast.zig
      well_formed.zig
      satisfaction.zig
      reach.zig
      normalize.zig
      residual.zig

    proof/
      proposition.zig
      plan.zig
      graph.zig
      run_plan.zig
      verify.zig
      certificate.zig

    games/
    observables/
    witnesses/

    constraints/       # existing CProp/checker backends
    schemas/           # existing concrete composition/data-flow IR
    types/
    catalog/
    emit/
```

The exact subdirectory split may change during implementation, but the ownership split must not.

## CompositionGraph is not replaced

`src/schemas/graph.zig::CompositionGraph` and Dep–Proof operate at different semantic layers.

`CompositionGraph` answers:

> What cryptographic values, operations, branches, and data flows constitute this concrete construction?

Dep–Proof answers:

> What must be present or proven about this scheme, what evidence discharges those obligations, and what depends on that evidence?

The composition graph is therefore one primary source for scheme state `S` and checkable facts. It should not be forced to encode proof binders, branch proof choice, universal quantification, or proof continuations.

## finite-math-kernels boundary

The integration direction is:

```text
crypto-composer
  DepSpec / Sat / verifier / certificate semantics
                │
                │ emits or consumes evidence records
                ▼
finite-math-kernels/proof_records
  identity / provenance / generic closure / graph
```

A complete `proof_records` closure says that the declared evidence-record graph is structurally complete under the consumer's policy. It does **not** imply that a cryptographic `Sat(S,D)` proposition is true.

That implication exists only when `crypto-composer` validates the evidence through its declared trusted proof/checker boundary.

## Other estate consumers

### objective-review-metasytem

May contain a Dep–Proof review/audit skill or manifesto rule set. It must not become the semantic owner of DepSpec or certificate checking.

### SpruceGoose

May emit deployment/test/release evidence that is translated into generic proof records. It is a producer/consumer of evidence, not the owner of Dep–Proof semantics.

### Halaqa / Senad+

May transport, attest, or package proof-carrying effects and certificate references. It must preserve identity/provenance rather than reinterpret proof truth.

### research repositories

May consume generic proof records and, where relevant, Dep–Proof-style obligation machinery. Their project-specific theorem status remains consumer policy.

## Why no new repository

A separate `dep-proof` repository would create three avoidable problems:

1. cryptographic semantics would be separated from the domain model and checker backends that define them;
2. generic evidence identity/closure would likely be duplicated from `finite-math-kernels`;
3. version skew between composition schemas, obligations, and security models would become an integration problem instead of an internal compatibility invariant.

The desired architecture is therefore a **two-repository boundary**, not a new island.

## Implementation sequence

1. Land the specification and architecture boundary.
2. Add `src/dep/` with AST, WF, reachability, and P0 normalization.
3. Add focused regression tests before implementation changes, following the repository's TDD/PDD rules.
4. Add `src/proof/` plan/graph/interpreter.
5. Adapt existing constraints into explicit `CProp` backends rather than rewriting them all at once.
6. Add proof-record adapter code at the boundary with `finite-math-kernels`.
7. Add GAME/OBS/WIT/RED domain objects incrementally.
8. Mechanize the minimal normalization/interpreter theorems in a selected proof assistant without moving semantic ownership out of `crypto-composer`.

## Invariant to preserve

There is one sentence reviewers should use as the boundary test:

> `crypto-composer` decides what a cryptographic obligation means and what evidence proves it; `finite-math-kernels` decides only whether generic evidence records are well-formed, content-addressed, and structurally complete under supplied policy.
