# Dep–Proof v2: scheme-indexed dependency and proof calculus

**Status:** corrected normative design specification for the planned formal core of `larsbx/crypto-composer`.

**Supersedes:** the September 19, 2026 draft on this branch.

**Scope:** dependency syntax, scheme-indexed semantics, well-formedness, normalization, proof-shaped VC planning, structured interpretation, verifier boundaries, evidence/certificate composition, and the interfaces to `finite-math-kernels` and `semantic-categorical-oracle`.

This document specifies intended semantics. It does **not** claim the implementation already exists.

## 0. Purpose and authority

Dep–Proof turns a dependency specification into an auditable proof/verification workflow for a concrete cryptographic construction or scheme state.

The domain authority remains `crypto-composer`:

- it defines the dependency language;
- it defines what `Sat` means;
- it defines which evidence proves a cryptographic obligation;
- it owns verifier adapters and certificate acceptance.

Two other repositories may support it without acquiring that authority:

- `larsbx/finite-math-kernels/kernel/proof_records/` owns generic evidence identity, provenance, dependency closure, and typed proof-record graph surfaces;
- `larsbx/semantic-categorical-oracle` may own explicitly registered executable **structural semantic contracts** such as canonical normal forms or preservation of branching, binders, sequencing, and composition. It does not own mathematical proof or certificate acceptance.

The high-level flow is:

```text
DepSpec + SchemeState
        │
        ├── WF
        │
        ├── AnalysisNF0 / AnalysisNF1
        │
        └── CompilePlan
               │
               ▼
            RunPlan
               │
               ├── Solved(Discharge)
               └── Pending(VCGraph, Open)
                                │
                                ▼
                        Extract / Verify / Plan
                                │
                                ▼
              ProofCertificate or EvidenceBundle
```

## 1. Normative invariants

1. **Scheme-indexed semantics.** The meaning of a specification is an obligation at a concrete scheme/state, never an implicit `∀S` statement.
2. **Frozen prerequisite arrow.** `a ⊸ b` means “`b` requires `a`”; `a` is the prerequisite and `b` is the dependent.
3. **Requires is not derives.** Prerequisite availability and proof sufficiency are distinct relations and must never share one untyped edge interpretation.
4. **True sequencing.** `D1 ; D2` must allow the second stage to depend on a post-state/evidence package produced by the first stage. A non-dependent pair is not sequencing.
5. **Closure is graph-theoretic.** `*` is defined using reachability on a selected required-edge relation.
6. **No total Boolean verifier.** Full propositions and checkable propositions are distinct; unknown never becomes proof.
7. **Syntax, satisfaction, and evidence are separate layers.**
8. **Analysis normalization is not proof hoisting.** A global conservative normal form may be used for caching/diffing/impact analysis, but branch-local obligations may not be hoisted across `∨`, `;`, or binders unless a preservation theorem justifies it.
9. **Kernel evidence is never dropped.** Every obligation used to reconstruct `Sat` must have a proof-consuming path into the final discharge.
10. **Evidence is explicit.** Reduction/simulator witnesses, composition laws, leakage models, assumptions, and bound side conditions are named artifacts.
11. **TCB is explicit.** Tool output becomes proof only through a declared trusted checker/kernel bridge.
12. **Authority is not promoted by translation.** Generic proof records or semantic-normalization oracles cannot by themselves establish cryptographic truth.

## 2. Core syntax

Assume decidable equality on element identifiers and finite syntactic support.

```text
Elem
Sort : Elem → Type
Kind(e) ∈ {slot, interface, prop}

Weight := req | opt | triv
Cond
```

### 2.1 Prerequisite atoms

The definedness dependency kernel uses:

```text
ReqAtom :=
  (prerequisite : Elem)
  (dependent    : Elem)
  (weight       : Weight)
  (guard        : Cond)
```

Notation:

```text
a ⊸ b
```

means `ReqAtom(a,b,req,⊤)`: **b requires a**.

### 2.2 Derivation relations

Proof sufficiency is represented separately:

```text
Derive :=
  (premise    : ClaimRef)
  (conclusion : ClaimRef)
  (transform  : WitnessRef)
  (model      : ReductionModel)
```

A `Derive` edge means that a named proof transformer may map evidence for the premise into evidence for the conclusion, subject to its model/side conditions.

This direction may match the premise → conclusion direction of the generic typed proof graph in `finite-math-kernels`; it must not be confused with prerequisite availability.

### 2.3 Dependency specifications

```text
StageVar
BinderVar

DepSpec :=
| req   : ReqAtom → DepSpec
| rich  : RichObligation → DepSpec
| and   : DepSpec → DepSpec → DepSpec       -- ∧
| or    : DepSpec → DepSpec → DepSpec       -- ∨
| tens  : DepSpec → DepSpec → DepSpec       -- ⊗
| seq   : DepSpec → (StageVar → DepSpec) → DepSpec
| all   : Binder → (BinderVar → DepSpec) → DepSpec
| star  : DepSpec → DepSpec
```

`StageVar` and `BinderVar` are **syntactic binders**, not semantic proof/state values. The semantics supplies substitutions/environments that map them to concrete stage results or binder values. A concrete implementation may use de Bruijn indices, named binders, a locally nameless representation, HOAS over abstract syntax variables, or another canonical binder representation. The syntax therefore does not depend circularly on `StageResult`, which is defined only at the semantic layer.

`CondDeps(c) : Finset Elem` returns all syntactic element references in a guard.

## 3. Scheme state, evidence context, and definedness

A scheme state supplies:

```text
SchemeState:
  inst : Elem → Option(Value(sort(e)))
  version : StateId
```

Definedness:

```text
def(S,e) := S.inst(e) ≠ none
```

Conditions have proposition semantics:

```text
evalProp(S,Γ,c) : Prop
```

where `Γ` is an evidence/binder context.

A decidable guard language may additionally expose:

```text
evalCond : SchemeState × EvidenceCtx × Cond → Bool
```

only with a trusted bridge theorem connecting `true` to `evalProp`.

Mandatory mechanization lemmas:

```text
def_of_inst  : inst(S,e) = some(v) → def(S,e)
def_elim     : def(S,e) → ∃v, inst(S,e) = some(v)
type_of_inst : inst(S,e) = some(v) → v : ⟦Sort(e)⟧
```

## 4. Declaration / satisfaction / proof separation

These are different objects:

```text
DeclDep          -- syntax/data
Sat(S,Γ,D)       -- proposition/type
Proof(Sat(...))  -- evidence
```

No declaration is itself a proof.

A proof record, test receipt, human attestation, or imported theorem is evidence **about** an obligation; it is not definitionally the proposition it supports.

## 5. Minimal well-formedness

`WF(D)` is static hygiene. It must not decide substantive security claims.

### WF-1 — finite support

`Nodes(D)` structurally collects:

- every prerequisite/dependent endpoint;
- every element in `CondDeps`;
- the finite syntactic support of rich obligations and binders.

It is finite and α-stable.

### WF-2 — kind/sort sanity

Definedness dependencies may connect any element kinds that the domain permits, but richer contracts must check their declared input/output kinds.

### WF-3 — guard hygiene

Initial mode:

- arbitrary syntactic guard dependencies are permitted;
- non-top guards are not inserted into P0;
- guarded obligations remain proof-plan obligations unless P1 activation supplies evidence.

### WF-4 — tensor footprint discipline

Define:

```text
Foot(D) : Finset Resource
```

For strict parallel composition:

```text
WF(D1 ⊗ D2) ⇒ Foot(D1) ∩ Foot(D2) = ∅
```

Any permitted sharing must be explicit in a richer interference model.

### WF-5 — binders

Two modes are permitted:

- finite enumerable binder expansion;
- symbolic binder preservation.

The second is the default.

### WF-6 — closure operands

The first mechanized `star` form is restricted to a **closure-eligible prerequisite fragment**:

- required prerequisite atoms;
- conjunction;
- compatible tensor composition where its prerequisite edges are interpreted conjunctively.

`∨`, `seq`, symbolic binders, and rich obligations are not silently flattened under `star`. A later extension may admit them only after defining a control-aware required-edge relation and proving that its closure semantics preserves the corresponding control structure.

## 6. Atomic prerequisite satisfaction

For:

```text
d = ReqAtom(a,b,req,c)
```

with `a` prerequisite and `b` dependent:

```text
SatReq(S,Γ,d)
  :=
  (evalProp(S,Γ,c) ∧ def(S,b))
  ⇒ def(S,a)
```

This is the frozen arrow convention made semantic: if the dependent is present and the guard is active, the prerequisite must be present.

Optional/trivial atoms do not create mandatory satisfaction in the minimal kernel:

```text
SatReq(S,Γ,ReqAtom(_,_,opt,_))  := ⊤
SatReq(S,Γ,ReqAtom(_,_,triv,_)) := ⊤
```

## 7. Compound satisfaction

For non-sequential constructors:

```text
Sat(S,Γ,D1 ∧ D2) := Sat(S,Γ,D1) × Sat(S,Γ,D2)

Sat(S,Γ,D1 ⊗ D2) := Sat(S,Γ,D1) × Sat(S,Γ,D2)
  subject to WF tensor compatibility

Sat(S,Γ,D1 ∨ D2) := Sat(S,Γ,D1) + Sat(S,Γ,D2)

Sat(S,Γ,∀x:τ.D(x)) := Π(x:τ). Sat(S,Γ+x,D(x))
```

Here `×` is evidence product and `+` is tagged evidence sum.

## 8. True sequential composition

A sequence stage produces more than a proof token.

Define:

```text
StageResult(S,Γ,D) :=
  {
    proof    : Proof(Sat(S,Γ,D)),
    post     : SchemeState,
    evidence : EvidenceCtx,
    refines  : Refines(S, Γ, post, evidence)
  }
```

The domain defines `Refines(inputState,inputEvidence,outputState,outputEvidence)`: it proves that the output state/context is an authorized refinement produced from the particular input state/context. The relation must preserve the provenance link to `Γ`; an arbitrary evidence context cannot be substituted merely because it validates the next stage.

For obligations that prove a fact without changing state or evidence, define a reflexive constructor:

```text
pureStage(S,Γ,π : Proof(Sat(S,Γ,D)))
  :=
  StageResult {
    proof    = π,
    post     = S,
    evidence = Γ,
    refines  = Refines.refl(S,Γ)
  }
```

This is the bridge used by atomic/kernel proof obligations; it prevents a bare proof term from being mistaken for a full stage transition.

Sequential satisfaction is:

```text
Sat(S,Γ, seq(D1,k))
  :=
  Σ(r1 : StageResult(S,Γ,D1)).
    Sat(
      r1.post,
      bindStageResult(Γ, k.var, r1),
      instantiateStage(k, r1)
    )
```

where `bindStageResult` extends the semantic environment with the concrete result bound to the syntax-level `StageVar`, and `instantiateStage` performs the corresponding capture-avoiding syntax substitution (or its chosen binder-representation equivalent).

This is genuinely dependent. The second component may depend on:

- the post-state;
- witnesses/evidence produced by stage one;
- the actual tagged branch/result encoded in `r1`.

A plain conjunction or non-dependent product cannot in general construct this type.

Operational implementations may use explicit state threading instead of exposing a dependent pair, provided the semantics are equivalent.

## 9. Reachability and prerequisite closure

The syntactic required-edge relation is stored in arrow direction:

```text
EdgeReq_D(a,b)
```

means `a ⊸ b`: b requires a.

Reachability is the reflexive-transitive closure:

```text
Reach(E) : Elem → Elem → Prop
| refl
| step
| trans
```

For a path from prerequisite `a` to downstream dependent `b`, definedness propagates **backwards**:

```text
SatStarReq(S,E)
  :=
  ∀a b.
    Reach(E,a,b)
    → (def(S,b) → def(S,a))
```

For a well-formed closure operand `D`, define its active required relation at the current state/context:

```text
ReqRelation(S,Γ,D)(a,b)
  :=
  ∃c.
    required ReqAtom(a,b,req,c) occurs in D
    ∧ evalProp(S,Γ,c)
```

with structural union over the closure-eligible conjunctive fragment.

The `star` constructor therefore has an explicit target proposition:

```text
Sat(S,Γ,star D)
  :=
  SatStarReq(S, ReqRelation(S,Γ,D))
```

This orientation and connection from `star D` to its control-local relation are normative.

## 10. P0 analysis normalization

P0 extracts only unconditional required atoms.

```text
ReqEdges0(req(ReqAtom(a,b,req,c)))
  = {(a,b)} if isTop(c)
  = ∅ otherwise

ReqEdges0(opt/triv) = ∅
```

For analysis purposes, structural extraction may conservatively union across `∧`, `⊗`, `∨`, and sequencing regions and may erase symbolic binders according to the declared binder policy.

Define:

```text
AnalysisNF0(D)
  := canon(TC_on_nodes(ReqEdges0(D), Nodes(D)))
```

For `(a,b) ∈ AnalysisNF0(D)`:

```text
VCedge(S,(a,b)) := def(S,b) → def(S,a)
```

and:

```text
AnalysisVCList0(S,D)
  := sorted map VCedge over AnalysisNF0(D)
```

### 10.1 What global AnalysisNF0 is for

It is valid for:

- deterministic graph inspection;
- diffing;
- caching;
- impact analysis;
- conservative static diagnostics;
- proving closure properties of a control-free fragment.

It is **not automatically a mandatory proof gate** for the whole `DepSpec` when the spec contains branch choice, sequencing, or binders.

In particular, unioning both sides of `D1 ∨ D2` may create extra VCs that are irrelevant to the chosen branch. Those VCs may be useful analysis facts but cannot be required for completeness of a proof of the disjunction.

## 11. Control-local kernel compilation

Certificate construction uses a control-preserving compiler.

An unconditional required atom becomes a proof obligation:

```text
need(
  VCedge(S,(a,b)),
  λp. done(
    pureStage(S,Γ,pack_req_sat(p))
  )
)
```

Kernel evidence is therefore threaded into the proof plan and cannot disappear.

Normalization may deduplicate/cache obligations **inside a control region** when a preservation theorem permits it.

The compiler must not hoist an obligation:

- out of one side of a `choose`;
- from stage two ahead of a `seq` gate;
- out from under a symbolic binder;

unless it has an explicit theorem proving the hoist preserves the plan semantics.

## 12. VCPlan

`VCPlan(G)` is a proof-directed recipe whose successful discharge returns a stage/result object for goal `G`.

Minimal constructors:

```text
done(r)
  where r : StageResult(...)

need(φ, k)
  where k : Proof(φ) → VCPlan

both(p,q,combine)

choose(p,q,injectLeft,injectRight)

forall(τ,f,assemble)

seq(p,q)
  where
    p : VCPlan(D1)
    q : StageResult(D1) → VCPlan(k(result))
```

The control structure is semantic, not scheduling decoration.

## 13. CompilePlan

Compilation is structural and deterministic.

### Required atoms

- unconditional required atom: emit a `need(VCedge,...)` whose continuation constructs `pureStage(..., pack_req_sat(p))`;
- guarded required atom: emit the guarded proposition directly, or under P1 require guard-activation evidence first, then construct a `pureStage` once proved;
- optional/trivial: construct the corresponding reflexive/pure stage with the trivial proof.

### Conjunction / tensor

Compile both and combine their stage results according to the domain's compatible post-state/evidence merge rule.

### Disjunction

```text
choose(CompilePlan(D1), CompilePlan(D2), ...)
```

No compiler heuristic commits to a branch.

### Sequencing

```text
seq(
  CompilePlan(D1),
  λr1.
    CompilePlanAt(
      r1.post,
      bindStageResult(Γ, k.var, r1),
      instantiateStage(k, r1)
    )
)
```

Stage two is neither opened nor normalized as an active proof obligation until stage one has produced the result it depends on.

### Universal binder

Finite mode expands deterministically.

Symbolic mode preserves:

```text
forall(τ, λx. CompilePlan(D(x)), assemble)
```

### Star

A `star D` node targets the declared proposition `SatStarReq(S, ReqRelation(S,Γ,D))` and uses a closure proof assembled from the active control-local required-edge obligations of its closure-eligible operand. It is not replaced by an untyped modal proposition.

## 14. Plan normalization

`PlanNF` may canonicalize without changing control semantics.

Allowed examples:

- flatten associative `both` nodes;
- sort commutative independent children with a canonical key;
- α-normalize binders;
- canonicalize proposition rendering;
- deduplicate identical obligations within a proven-equivalent control region.

Forbidden without a theorem:

- merging evidence across disjunction branches;
- moving stage-two obligations before a sequence gate;
- erasing binder context;
- replacing a dependent sequence with a product.

## 15. VCGraph

`RunPlan` lowers a plan to a solved result or a structured graph.

A proposition node records:

```text
VCNode:
  id
  path
  ctx
  prop
  class ∈ {checkable, uncheckable, unknownYet}
  deps
  onProved : Proof(prop) → Continuation
```

Control nodes:

- `SeqGate`: stage two is unavailable until a `StageResult` for stage one exists;
- `ChoiceGate`: one tagged branch establishes the disjunction; evidence from distinct branches is not mixed;
- `ForallGate`: preserves binder context or finite instantiation policy;
- optional `JoinGate`: combines compatible independent results for `both`/`⊗`.

## 16. RunPlan

`RunPlan` is pure and deterministic. It compiles; it does not invoke solvers or guess branches.

```text
RunPlan(S,Γ,plan)
  →
  Solved(StageResult)
  | Pending(VCGraph, OpenIds)
```

Behavior:

- `done` returns solved;
- `need` emits one obligation with continuation;
- `both` compiles both allowed sides and joins only when both results exist;
- `choose` preserves branch separation;
- `forall` expands or preserves a gate;
- `seq` compiles stage one first and opens stage two only after receiving its `StageResult`.

## 17. Prop / CProp / verification

Full propositions are not assumed decidable.

```text
Prop
CProp

Extract : Prop → Option(CProp)

Verify :
  SchemeState × EvidenceCtx × CProp
  →
  sat(cert)
  | unsat(counterexample)
  | unknown(explanation)

Plan : Prop → VCPlan
```

`unknown` yields no proof.

### 17.1 Environment grounding

Every checkable VC is interpreted under an explicit environment `Σ`.

A distinguished root obligation checks consistency/non-vacuity:

```text
VCEnvConsistent(Σ)
```

For this root alone, SAT may be success.

For universal VCs encoded to SMT:

```text
check encode(Σ) ∧ ¬encode(vc)

UNSAT   => proof relative to encoding/TCB
SAT     => counterexample
UNKNOWN => no proof
```

Every artifact records `envHash`.

### 17.2 Instantiation/readiness

`VCInst(e)` is a kernel lookup, not an SMT query.

A derived `VCElemReady(e)` may summarize:

- instantiation;
- type/local contracts;
- prerequisite readiness;
- required predecessor evidence.

## 18. P1 evidence-driven guard activation

Define:

```text
Active(S,Γ,c) : Prop
```

An active guarded prerequisite edge is:

```text
Edge1(S,Γ,D,Ev)(a,b)
```

iff `ReqAtom(a,b,req,c)` occurs and `Ev` contains accepted evidence for `Active(S,Γ,c)`.

Then:

```text
AnalysisNF1(D,Ev)
  := canon(TC_on_nodes(active required edges, Nodes(D)))
```

Guard evidence growth is monotone:

```text
Ev ⊆ Ev'
⇒
AnalysisNF1(D,Ev) ⊆ AnalysisNF1(D,Ev')
```

If syntactic-top guards are always active, every P0 edge is a P1 edge.

This is a refinement of the analysis relation; certificate compilation still preserves control structure.

## 19. Explicit existential witnesses

Bare existential proof obligations do not count as evidence.

Use named, pinned artifacts:

```text
VCWitnessExists(ref)
VCWitnessCorrect(ref,spec)

VCReductionWitness(ref,from,to,loss,model)
VCSimulatorWitness(ref,real,ideal,bound,model)
```

A reduction/simulator reference must identify the artifact and its side conditions.

## 20. Security-bound composition

The default generic rule is the union bound when applicable:

```text
ε_total ≤ Σ_i ε_i
```

**Probabilistic independence alone never licenses `max`.**

Non-default composition uses an explicit theorem-bearing object:

```text
ComposeLaw:
  id
  model
  inputs
  sideConditions
  boundTransform
  proofRef
```

Examples may include:

- union bound;
- independent-event composition such as `1 - Π_i(1-ε_i)` where its event model applies;
- hybrid-specific tightness theorems;
- a `max` rule only when a named theorem actually proves that rule for the declared composition.

Bound expressions generate well-formedness VCs such as:

```text
VCParamDefined
VCParamPositive
VCParamType
VCIsSecurityParam
VCNonZero
VCPowWellDefined
VCProbabilityRange
VCComposeLawApplicable
```

Iteration counts come from named parameters, never guessed from syntax.

## 21. Leakage / constant-time claims

Constant-time is noninterference relative to an explicit observation model.

```text
VCConstTime(f,secrets,publics,LeakageModel)
```

The model records at least:

- timing granularity;
- variable-time operations;
- memory/cache observation;
- branch observation;
- speculation model;
- secret annotation discipline.

A tool result proves only the model it covers.

## 22. Stable identities and provenance

Canonical path vocabulary:

```text
root
.left / .right
.seq1 / .seq2
.forall[x]
.need[h(prop)]
```

VC identity:

```text
VCID :=
  H(
    versionTag
    ∥ canonical(obligation)
    ∥ canonical(origin)
    ∥ canonical(relevantEnvSlice)
  )
```

Graph-node identity additionally includes binder/control context.

Cache keys include at least:

- VCID;
- strategy hash;
- exact tool version;
- tool binary hash.

## 23. Evidence classes and claim levels

Evidence classes:

```text
Kernel
ProofObject
ToolRun
HumanAttestation
ImportedTheorem
```

Claim status:

```text
Proven(evidence)
Conditional(assumptions,evidence)
Claimed
Pending(reason)
```

No translation silently promotes authority.

## 24. Proof certificates versus evidence bundles

These are intentionally different artifacts.

### 24.1 ProofCertificate

```text
ProofCertificate(S,Γ,D)
  := Proof(Sat(S,Γ,D))
```

It contains only evidence sufficient to construct the proposition.

### 24.2 EvidenceBundle

An `EvidenceBundle` may also contain:

- conditional claims;
- human attestations;
- claimed/pending obligations;
- counterexamples;
- incomplete branches;
- tool runs that did not yield a proof.

An EvidenceBundle is audit material and must not be presented as a `ProofCertificate`.

Both may record:

- scheme/spec identity;
- `envHash`;
- stable VCIDs;
- normalization/plan identities;
- proof-record references;
- tool/reviewer metadata;
- leakage and composition models.

## 25. Generic proof-record integration

The generic evidence substrate is currently:

```text
larsbx/finite-math-kernels/kernel/proof_records/
```

It owns generic:

- content-derived record identity;
- canonical serialization;
- evidence classes/outcomes;
- identity-bearing dependency edges;
- dependency alternatives;
- structural closure;
- typed relationship graph surfaces;
- proof-graph representation normalization.

It does **not** own:

- `Sat`;
- crypto game truth;
- certificate acceptance;
- reduction correctness;
- leakage-model adequacy.

A complete generic record closure is not definitionally a Dep–Proof certificate.

### 25.1 Edge-direction boundary

FMK's typed proof graph may use premise → conclusion for proof sufficiency.

Dep–Proof's prerequisite arrow uses prerequisite → dependent syntax but backward definedness implication:

```text
a ⊸ b      means b requires a
Reach(a,b) gives def(b) → def(a)
```

Adapters must type these relations explicitly; no edge may be translated by position alone.

## 26. Structural semantic oracle integration

`larsbx/semantic-categorical-oracle` may implement an explicitly registered `dep-proof-structure/v1` contract **after** the domain publishes canonical vectors.

Permitted normative questions may include:

- AST interpretation;
- canonical normal form;
- α-equivalence;
- preservation of branch separation;
- preservation of binder context;
- preservation of sequencing/control gates;
- composition-preserving rendering.

Globally excluded authority remains:

- mathematical proof;
- cryptographic certificate acceptance;
- effect authorization;
- persisted state.

The domain-owned vectors/specification remain in `crypto-composer`; Haskell may become the executable semantic oracle for the registered structural questions only.

## 27. Trusted computing base

Each certificate profile names its TCB.

At minimum:

1. `Sat` and sort/kind interpretation;
2. state/evidence transition semantics for `StageResult`;
3. the proof kernel or proof-object checker;
4. the `CProp` verifier-to-proof bridge;
5. canonical serialization/hash routines;
6. compiler/interpreter correctness assumptions until mechanized;
7. imported theorem trust and hypothesis checking;
8. each non-default `ComposeLaw` theorem/reference.

## 28. Corrected theorem ledger

### Structural

**T1 — compositionality.** `Sat` follows the declared constructors.

**T2 — dependency-closed refinement monotonicity.**

Arbitrary increase of definedness is **not** monotone.

A valid theorem requires:

```text
ClosedRefinement(S,Γ,D,S',Γ')
∧ Sat(S,Γ,D)
⇒ Sat(S',Γ',D)
```

where `ClosedRefinement` proves that newly available dependents do not appear without all prerequisites/guards/evidence required by `D`.

**T3 — weakening in specification strength.**

For an explicitly defined preorder:

```text
D1 ⊑ D2
⇒
Sat(S,Γ,D2) ⊢ Sat(S,Γ,D1)
```

subject to the constructor-specific preorder rules.

### Sequencing

**T4 — first-stage projection.** A sequential discharge exposes its first `StageResult`.

**T5 — non-collapse.** There is no generic context-free map from independent proofs of `D1` and a pre-state `D2` into a proof of the dependent sequence when `D2` depends on `r1.post` or `r1.evidence`.

**T6 — associativity.** Holds only after defining and proving associativity of the state/evidence transition/merge semantics.

**T7 — unit laws.** Hold only for an explicit neutral stage result and transition law.

### Prerequisite closure

**T8 — reachability reflexivity.**

**T9 — reverse definedness propagation transitivity.**

If `Reach(a,b)` and `Reach(b,c)`, then the closure proof composes the two reverse implications internally and yields:

```text
def(c) → def(a)
```

The intermediate `def(b)` is derived from `def(c)`; it is not an additional caller-supplied premise.

**T10 — closure idempotence.**

**T11 — every one-step required edge is represented in closure.**

### P0 analysis normalization

For a control-free prerequisite fragment, define `SatStar0` using the corrected reverse implication.

**NF-Sound.**

```text
SatStar0(S,D)
⇒
⋀ AnalysisVCList0(S,D)
```

**NF-Complete (fragment-local).**

```text
⋀ AnalysisVCList0(S,D)
⇒
SatStar0(S,D)
```

provided computed transitive closure exactly represents `Reach` on `Nodes(D)`.

**NF-Compare.**

Equal canonical analysis normal forms imply equal kernel-analysis conjunctions.

**No full-language completeness claim** is made for a global union across `∨`, sequencing, or symbolic binders.

### P1

**P1 edge inclusion.** Top-guard P0 edges are contained in P1 when top is active.

**P1 evidence monotonicity.**

```text
Ev ⊆ Ev'
⇒ AnalysisNF1(D,Ev) ⊆ AnalysisNF1(D,Ev')
```

### Compiler/interpreter

**C1 — obligation preservation.** Every atomic obligation needed by the final `Sat` proof has a proof-consuming path in the compiled plan.

**C2 — control preservation.** Compilation preserves branch separation, sequencing gates, and binder context.

**E1 — solved soundness.** `RunPlan = Solved(r)` implies the result contains a proof of the goal satisfaction at the declared state/context.

**E2 — pending-graph soundness.** Any assignment of proofs to open proposition nodes that respects all gates reconstructs a solved result.

**E3 — causal progress.** Newly generated obligations arise only from continuations downstream of already discharged nodes/gates.

### Verification/certificates

**V1 — CProp verifier soundness.** `sat(cert)` yields a proof only through the declared trusted checker.

**V2 — ProofCertificate soundness.** A well-formed `ProofCertificate(S,Γ,D)` inhabits `Sat(S,Γ,D)`.

**V3 — EvidenceBundle non-promotion.** Presence of claimed/pending/conditional evidence never implies a ProofCertificate without the required proof bridge.

## 29. Incremental verification

Incremental recheck is parameterized by a **change model**.

For a required-edge VC:

```text
def(dependent) → def(prerequisite)
```

the truth value can change if either endpoint's definedness or any relevant guard/context changes.

Therefore an implementation computes affected obligations from:

- changed scheme elements;
- changed guards/evidence;
- control-region activation;
- the declared influence relation.

An up-closure optimization is valid only when a theorem proves omitted endpoints and guards cannot change under the chosen update model.

## 30. Categorical restraint

Required claims are modest:

- dependency specs may form a preorder after the chosen equivalence/quotient;
- propositions form an entailment preorder;
- stronger well-defined specs entail weaker obligations under the declared preorder.

No adjunction, cartesian closure, thin-category identification, or fibration theorem is claimed without the formal categories/functors and proof.

A fibration/comprehension interpretation remains a useful design guide, not a theorem by prose.

## 31. Crypto-specific extension axes

The security layer should separate:

```text
Σ_GAME
Σ_OBS
Σ_WIT
Σ_RED
```

where:

- GAME owns security worlds/oracles/win predicates;
- OBS owns views/leakage models;
- WIT owns relations/verifiers/extractors;
- RED owns explicit proof transformers, models, costs, losses, and composition laws.

These generate rich obligations; they do not replace the Dep–Proof kernel.

## 32. Initial implementation layout

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

  constraints/      # existing checks become CProp backends
  schemas/          # CompositionGraph remains concrete construction/data-flow IR
  emit/
```

`CompositionGraph` remains a source of scheme state/checkable facts. It is not replaced by the proof calculus.

## 33. Mechanization order

First slice:

1. finite `Elem`;
2. `ReqAtom` with frozen prerequisite orientation;
3. `SchemeState` and definedness;
4. inductive `Reach`;
5. corrected `SatReq` and `SatStarReq`;
6. `Nodes`, `ReqEdges0`, `AnalysisNF0`;
7. NF soundness/completeness for the control-free fragment;
8. a minimal `StageResult`;
9. `VCPlan` with `done/need/both/seq`;
10. compiler obligation-preservation;
11. `RunPlan` solved/pending soundness.

Only then add:

- `∨`;
- binders;
- P1;
- rich crypto contracts;
- solver adapters;
- semantic-oracle conformance vectors.

## 34. First implementation acceptance criteria

A first conforming slice must prove by tests and/or mechanization that:

1. `a ⊸ b` rejects a state where `b` is defined and `a` is not;
2. the same relation does not reject merely because `a` exists without `b`;
3. sequencing syntax binds an abstract `StageVar`, and stage two can depend on the concrete stage-one post-state/evidence only through capture-avoiding semantic instantiation;
4. replacing the sequence with a product fails a negative test;
5. every unconditional kernel atom in a final proof has a proof-consuming plan node whose continuation constructs a reflexive `pureStage`, not a bare proof masquerading as a stage result;
6. branch-local obligations cannot be satisfied by mixing evidence from two `choose` branches;
7. `AnalysisNF0` is deterministic;
8. global analysis normalization is not used as a mandatory disjunction proof gate;
9. arbitrary definedness extension is not accepted as a monotonicity theorem;
10. non-default security bound composition names a `ComposeLaw`;
11. `unknown` never yields proof;
12. an FMK proof-record closure does not automatically become a ProofCertificate;
13. a structural oracle result never acquires certificate-acceptance authority.

## 35. Non-goals

Dep–Proof does not:

- decide arbitrary cryptographic propositions;
- identify prerequisite edges with proof-sufficiency edges;
- infer reductions/simulators from labels;
- promote empirical evidence to theorem status;
- promote generic proof-record closure to cryptographic proof;
- use independence as a generic license for a `max` bound;
- flatten branching, binders, or sequencing into a proof-obligation list;
- move certificate acceptance into `finite-math-kernels` or `semantic-categorical-oracle`;
- replace `CompositionGraph`.
