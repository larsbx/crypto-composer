# ADR: Dep–Proof placement in the repository estate

**Decision:** Dep–Proof remains domain-owned by `larsbx/crypto-composer`, but the estate now has a three-layer authority model:

1. `crypto-composer` — cryptographic domain/proof authority;
2. `finite-math-kernels/kernel/proof_records` — generic evidence/provenance substrate;
3. `semantic-categorical-oracle` — optional executable authority for explicitly registered structural semantic contracts only.

**Status:** revised architecture decision, October 22, 2026.

## 1. Why this revision exists

The September 19 placement analysis correctly concluded that Dep–Proof should not become a new standalone repository and that generic evidence identity/closure belongs outside `crypto-composer`.

Two things changed after that decision:

- `finite-math-kernels` expanded its proof-record subsystem with dependency alternatives and a domain-owned typed-proof-graph normalization contract;
- `larsbx/semantic-categorical-oracle` became the estate's home for versioned executable semantic contracts, with an explicit authority firewall excluding mathematical proof and certificate acceptance.

The revised placement preserves the original ownership boundary while recognizing that structural semantics can now have an independent oracle.

## 2. Canonical domain owner: crypto-composer

`crypto-composer` owns every question whose answer can change cryptographic proof or certificate acceptance:

- DepSpec syntax;
- `Requires` versus `Derives` relation typing;
- scheme/state interpretation;
- `Sat(S,Γ,D)`;
- stage/state/evidence transition semantics;
- P0/P1 obligation meaning;
- GAME/OBS/WIT/RED domain objects;
- trusted verifier adapters;
- reduction/simulator correctness criteria;
- security-bound composition-law applicability;
- leakage-model adequacy;
- construction of `ProofCertificate`;
- final certificate acceptance.

The corrected domain specification is `docs/DEP_PROOF_SPEC.md`.

## 3. Existing crypto-composer anchors

| Responsibility | Existing location | Relationship to Dep–Proof |
| --- | --- | --- |
| Primitive/interface contracts | `src/types/contracts.zig` | scheme/domain values |
| Assumptions | `src/types/assumptions.zig` | named crypto assumptions |
| Concrete construction IR | `src/schemas/graph.zig` | source of scheme/data-flow state |
| Checkable constraints | `src/constraints/` | future CProp backends |
| Constraint dispatcher | `src/constraints/checker.zig` | future verifier adapter surface |
| Proof-associated tests | `test/harness.zig` | PDD metadata, not proof terms |
| Artifact emission | `src/emit/artifact.zig` | future certificate/evidence emission |
| Red/green execution ledger | `tdd_ledger.zig` | execution provenance, not theorem authority |

The current `CompositionGraph` remains the concrete construction/data-flow IR. Dep–Proof sits above it.

## 4. Generic evidence owner: finite-math-kernels

The current reusable package is:

```text
larsbx/finite-math-kernels/kernel/proof_records/
```

It owns generic:

- canonical record identity;
- canonical serialization;
- evidence kinds/outcomes;
- identity-bearing dependency edges;
- dependency alternatives;
- structural closure;
- typed relationship-graph export;
- domain-owned proof-graph representation normalization.

It does not decide:

- cryptographic `Sat`;
- whether a reduction is correct;
- whether a security theorem follows;
- whether a leakage model is adequate;
- whether a cryptographic certificate is accepted.

A complete proof-record closure is therefore an evidence-graph fact, not automatically a Dep–Proof `ProofCertificate`.

### 4.1 Edge-type warning

The generic typed proof graph uses premise → conclusion for proof sufficiency.

Dep–Proof's prerequisite arrow is:

```text
a ⊸ b
```

meaning “b requires a”, and its definedness obligation is:

```text
def(b) → def(a)
```

Adapters must type those relations explicitly. No generic graph edge may be interpreted merely from its source/target positions.

## 5. Structural semantic oracle: semantic-categorical-oracle

The estate now has a dedicated executable semantic-contract layer.

A future domain-owned contract such as:

```text
dep-proof-structure/v1
```

may authorize `semantic-categorical-oracle` to answer only explicitly registered structural questions such as:

- AST interpretation;
- canonical normal form;
- α-equivalence;
- preservation of branching;
- preservation of binder context;
- preservation of sequencing gates;
- composition-preserving rendering.

The domain must first publish:

- the contract;
- canonical vectors;
- authority scope;
- excluded questions;
- approval evidence.

The oracle does **not** acquire authority over:

- mathematical proof;
- cryptographic certificate acceptance;
- effect authorization;
- persisted state.

This matches the oracle repository's current authority boundary.

## 6. Revised architecture

```text
                       crypto-composer
                 DOMAIN / PROOF AUTHORITY
           DepSpec, Sat, crypto semantics, TCB,
             trusted checkers, cert acceptance
                    /                 \
                   /                   \
                  / structural          \ evidence
                 / contracts             \
                ▼                         ▼
semantic-categorical-oracle     finite-math-kernels
 STRUCTURAL SEMANTICS ORACLE      EVIDENCE SUBSTRATE
 interpretation / normal form     proof_records
 branch/binder/seq preservation   identity / provenance
 composition preservation         closure / alternatives
 no certificate acceptance        typed evidence graph
```

This is a three-layer authority model, not three competing implementations.

## 7. Why Dep–Proof still does not get its own repository

A standalone Dep–Proof repository would still create unnecessary semantic version skew:

- crypto contract/schema changes would have to synchronize across repositories;
- certificate acceptance would be separated from the checker/domain model that defines it;
- generic proof-record functionality would risk duplication;
- structural semantic-oracle authority would be harder to scope to domain-owned vectors.

The domain specification and implementation therefore remain in `crypto-composer`.

## 8. Intended crypto-composer layout

```text
src/
  dep/
    ast.zig
    well_formed.zig
    satisfaction.zig
    reach.zig
    analysis_normalize.zig
    compile_plan.zig

  proof/
    proposition.zig
    stage_result.zig
    plan.zig
    graph.zig
    run_plan.zig
    verify.zig
    certificate.zig

  games/
  observables/
  witnesses/
  reductions/

  constraints/
  schemas/
  types/
  catalog/
  emit/
```

## 9. CompositionGraph boundary

`CompositionGraph` answers:

> What values, operations, branches, and flows make up this concrete construction?

Dep–Proof answers:

> What prerequisites and proof obligations must this construction satisfy, what evidence discharges them, and how does proof control flow depend on earlier results?

Neither should absorb the other.

## 10. Other estate consumers

### objective-review-metasytem

May consume the general structured-plan ideas and may have its own semantic contract in `semantic-categorical-oracle`. It is not the owner of cryptographic Dep–Proof semantics.

### SpruceGoose

May emit release/execution evidence into the generic proof-record vocabulary. It does not own Dep–Proof truth.

### Halaqa / Senad+

May transport or attest certificate/evidence references. Production verifier authority remains with the designated verifier.

### Research repositories

May reuse proof-record or structured-obligation patterns, but theorem status remains local consumer policy/proof authority.

## 11. Current implementation sequence

1. Repair the `crypto-composer` repository/toolchain gate.
2. Land the corrected Dep–Proof specification.
3. Implement `Requires` orientation, WF, Reach, and control-free P0 analysis under red-first PDD/TDD.
4. Implement `StageResult`, `VCPlan`, and `RunPlan`.
5. Integrate existing constraints as explicit checkable backends.
6. Add the FMK proof-record adapter with typed relation mapping.
7. Publish domain-owned structural vectors.
8. Only then register/promote a Dep–Proof structural contract in `semantic-categorical-oracle`.
9. Add GAME/OBS/WIT/RED layers incrementally.

## 12. Review invariants

Use these three questions during review:

> Does this change alter what a cryptographic obligation means or what proves it?  
> If yes, it belongs under crypto-composer domain authority.

> Does this change only encode, identify, relate, or close generic evidence records?  
> If yes, it belongs under finite-math-kernels proof_records authority.

> Does this change only give executable meaning to an explicitly registered structural contract with domain-owned vectors?  
> If yes, it may belong under semantic-categorical-oracle authority, but never certificate acceptance.
