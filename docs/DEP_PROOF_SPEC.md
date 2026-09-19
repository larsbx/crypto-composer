# Dep–Proof: scheme-indexed dependency and proof calculus

**Status:** normative design specification for the next formal core of `larsbx/crypto-composer`.

**Scope:** this document specifies the dependency language, scheme-indexed semantics, normalization kernel, residual proof planning, obligation-graph interpreter, verification boundary, certificates, and metatheorem obligations. It does **not** claim that these components are already implemented.

## 0. Purpose and architectural position

Dep–Proof turns a dependency specification into an audit-ready proof and verification workflow.

For a concrete scheme or scheme state `S` and dependency specification `D`, the system must produce:

1. a canonical unconditional dependency kernel,
2. a proof-shaped residual obligation plan that preserves sequencing, branching, and binders,
3. either a proof of scheme-specific satisfaction or a structured graph of outstanding obligations,
4. a certificate whose evidence, provenance, assumptions, models, and tool boundary are explicit.

The core semantic object is:

```text
Sat(S, D)
```

Dependencies therefore mean obligations **at a scheme/state**, not global claims about every possible implementation.

The principal compilation spine is:

```text
DepSpec
  │
  ├── WF
  │
  ├── P0 kernel: ReqEdges0 → NF0 → VCList0
  │
  └── ResidualPlanNF
          │
          ▼
       RunPlan
          │
          ├── Solved(Proof(Sat(S,D)))
          └── Pending(VCGraph, Open)
                         │
                         ▼
                 Extract / Verify / Plan
                         │
                         ▼
                     Certificate
```

P1 refines P0 by admitting guarded dependency edges only after guard evidence is available.

## 1. Design invariants

The following are normative.

1. **Scheme-indexed semantics.** `Sat(S,D)` is primitive. A dependency declaration is not itself a proposition and is never silently generalized to `∀S`.
2. **Frozen arrow convention.** `a ⊸ b` means “`b` requires `a`” / “`b` depends on `a`”.
3. **Non-collapsing sequencing.** `D1 ; D2` is interpreted by dependent sequencing (Σ/let), not conjunction.
4. **Graph-theoretic closure.** `D*` means reachability over the selected required-edge relation.
5. **No total Boolean verifier.** Full propositions and checkable propositions are distinct.
6. **Declarations, satisfaction, and proofs are separate layers.**
7. **Normalization is conservative.** P0 is deterministic and cacheable; it may over-generate kernel obligations but must not silently erase higher structure.
8. **Residual structure is preserved.** `∨`, `∀`, and `;` are represented by structured plan/gate nodes, never flattened into a list.
9. **Evidence is explicit.** Reductions, simulators, independence claims, leakage models, and bound side conditions require named evidence.
10. **TCB is explicit.** A tool result becomes a proof only through a stated trusted checker or kernel rule.

## 2. Core syntax

Assume a finite syntactic support and decidable equality on elements.

```text
Elem
Sort : Elem → Type
Kind(e) ∈ {slot, interface, prop}

Weight := req | opt | triv

Atom :=
  (a : Elem)
  (b : Elem)
  (w : Weight)
  (c : Cond)

DepSpec :=
| atom  : Atom → DepSpec
| and   : DepSpec → DepSpec → DepSpec       -- ∧
| or    : DepSpec → DepSpec → DepSpec       -- ∨
| tens  : DepSpec → DepSpec → DepSpec       -- ⊗
| seq   : DepSpec → DepSpec → DepSpec       -- ;
| all   : Binder → DepSpec → DepSpec        -- ∀
| star  : DepSpec → DepSpec                  -- *
```

`CondDeps(c) : Finset Elem` returns all element names referenced syntactically by a condition.

Optional modalities, guards, richer contracts, and additional weights may be introduced as syntax sugar or extensions, but they must elaborate into the kernel without changing these invariants.

## 3. Scheme state and definedness

A scheme instance/state provides:

```text
inst_S : Elem → Option(Value(sort(e)))
def_S(e) := inst_S(e) ≠ none
```

A condition has proposition semantics:

```text
⟦c⟧_S : Prop
```

When a condition language is decidable, an implementation may also expose:

```text
evalCond_S : Cond → Bool
```

with a trusted bridge theorem between `evalCond_S(c) = true` and `⟦c⟧_S`.

Mandatory definedness/type lemmas:

```text
def_of_inst  : inst_S(e) = some(v) → def_S(e)
def_elim     : def_S(e) → ∃v, inst_S(e) = some(v)
type_of_inst : inst_S(e) = some(v) → v : ⟦Sort(e)⟧
```

The implementation must also provide definitional equality/rewrite lemmas for sort interpretation.

## 4. Three-layer dependency discipline

The implementation must distinguish:

```text
DeclDep(a,b,w,c)  -- syntax/data
SatDep_S(d)       -- proposition that S satisfies declaration d
Proof_S(d)        -- evidence inhabiting SatDep_S(d)
```

A dependent scheme record may be presented as:

```text
Scheme(D) :=
  Σ(values).
  Π(d ∈ D). Proof(SatDep_S(d))
```

This separation is required to prevent dependency declarations, semantic claims, and evidence from being conflated.

## 5. Satisfaction semantics

For a required atom `d = atom(a,b,req,c)`:

```text
Sat(S,d) := (⟦ c⟧_S ∧ def_S(a)) ⇒ def_S(b).
```

Under the minimal kernel policy, optional and trivial atoms do not contribute mandatory satisfaction:

```text
Sat(S,atom(_,_,opt,_)) := ⊤,
qquad
Sat(S,atom(_,_,triv,_)) := ⊤.
```

Compound semantics:

```text
Sat(S,D_1 ∧ D_2) := Sat(S,D_1)∧ Sat(S,D_2),
```

```text
Sat(S,D_1 ⊗ D_2) := Sat(S,D_1)× Sat(S,D_2),
```

```text
Sat(S,D_1 ∨ D_2) := Sat(S,D_1)∨ Sat(S,D_2),
```

```text
Sat(S,∀ x{:}τ.D(x)) := Π(x{:}τ).Sat(S,D(x)).
```

### 5.1 Sequential composition

Sequential composition is evidence-sensitive:

```text
Sat(S,D_1;D_2)
:=
Σ(pi_1:Sat(S,D_1)).Sat(S,D_2).
```

Operationally, an implementation may use state threading `S → S'`; however, the logical presentation must preserve the same evidence dependency.

The semantics must **not** be replaced by:

```text
Sat(S,D1) ∧ Sat(S,D2)
```

or by `φ1 ∧ (φ1 → φ2)`, both of which erase the evidence-sensitive sequencing discipline.

## 6. Reachability and closure

For an edge relation `E : Elem → Elem → Prop`:

```text
Reach(E) : Elem → Elem → Prop
| refl  : Reach E a a
| step  : E a b → Reach E a b
| trans : Reach E a b → Reach E b c → Reach E a c
```

Closure is a graph-level concept.

For the selected edge relation `Edge_D`:

```text
SatStar(S,Edge_D)
:=
∀ a,b. Reach(Edge_D)(a,b)
⇒ (def_S(a)⇒ def_S(b)).
```

`Sat(S,D*)` is defined through this reachability semantics, not through an unspecified logical fixed-point modality.

## 7. Minimal well-formedness kernel

`WF(D)` is syntactic hygiene. It must not smuggle substantive security/correctness claims into well-formedness.

### WF-1 — finite support

`Nodes(D) : Finset Elem` structurally collects:

- every atom endpoint,
- every element in `CondDeps(c)`,
- the finite syntactic support of binder bodies.

`WF(D)` guarantees that this support is finite and stable under α-renaming.

### WF-2 — lightweight kind sanity

Definedness propagation itself is sort-agnostic, but richer contracts must be kind-compatible. The minimal kind set is:

```text
{slot, interface, prop}
```

Value-level or interface-level obligations may add more precise contract typing later.

### WF-3 — guard hygiene

The first implementation uses the explicit/non-stratified policy:

- guards may mention arbitrary syntactic elements,
- P0 ignores non-top guards,
- guarded dependencies remain residual obligations,
- P1 may activate them when evidence is supplied.

A future stratified-guard mode may require condition dependencies to be available in an earlier sequencing stratum.

### WF-4 — parallel footprint discipline

Define:

```text
Foot(D) : Finset Elem
```

For `D1 ⊗ D2` require:

```text
Foot(D_1)∩ Foot(D_2)=∅.
```

Any later relaxation must make ownership, sharing, or interference explicit.

### WF-5 — binder discipline

Two modes are permitted:

- **finite expansion:** `∀x:τ` only when `τ` is finite/enumerable;
- **binder residual:** the kernel does not expand the binder and the quantified obligation remains in the residual plan.

The second mode is the default first implementation.

## 8. P0 kernel normalization

P0 extracts a deterministic, unconditional, conservative dependency kernel.

### 8.1 Required-edge extraction

```text
ReqEdges0(atom(a,b,req,c))
  = {(a,b)} if isTop(c)
  = ∅ otherwise

ReqEdges0(atom(_,_,opt,_))  = ∅
ReqEdges0(atom(_,_,triv,_)) = ∅

ReqEdges0(and D1 D2)  = ReqEdges0(D1) ∪ ReqEdges0(D2)
ReqEdges0(or  D1 D2)  = ReqEdges0(D1) ∪ ReqEdges0(D2)
ReqEdges0(tens D1 D2) = ReqEdges0(D1) ∪ ReqEdges0(D2)
ReqEdges0(seq D1 D2)  = ReqEdges0(D1) ∪ ReqEdges0(D2)
ReqEdges0(all x D)    = binder-policy extraction
ReqEdges0(star D)     = ReqEdges0(D)
```

Union over `or` is deliberately conservative. Binder-residual mode includes only syntactically unconditional edges that do not depend on the binder; otherwise quantified structure remains residual.

Define:

```text
Edge0_D(a,b) := (a,b) ∈ ReqEdges0(D).
```

### 8.2 Canonical closure

On `Nodes(D)`, compute reflexive-transitive closure and canonicalize:

```text
NF0(D)
:=
canon(TC_on_nodes(ReqEdges0(D),Nodes(D))).
```

`canon` uses a fixed total order, deterministic serialization, and deduplication.

An implementation may use Floyd–Warshall, bitset transitive closure, repeated squaring, or another exact finite algorithm. Algorithm choice is not semantic.

### 8.3 Kernel VCs

For a normalized edge:

```text
VCedge(S,(a,b)) := def_S(a)⇒ def_S(b).
```

Then:

```text
VCList0(S,D)
:=
map(VCedge(S),toSortedList(NF0(D))).
```

The list is canonical, duplicate-free, stable, and content-addressable.

## 9. VC normal form

The full normalization result is conceptually:

```text
VNF(D)=(𝓔,𝓒,𝓠)
```

where:

- 𝓔 is the canonical P0/P1 closed edge relation,
- 𝓒 records guard policy and condition obligations,
- 𝓠 preserves higher structure as residual proof obligations.

Normalization must never pretend to decide disjunctions, arbitrary guards, cryptographic claims, or unbounded quantification.

## 10. Residual proof planning

A residual obligation list is insufficient because it destroys sequencing, branching, and binders.

Define a proof-shaped planning language `VCPlan(S,D)`:

```text
done(π)
  where π : Proof(Sat(S,D))

need(φ, k)
  where k : Proof(φ) → VCPlan(S,D)

both(p,q)
  -- conjunction / compatible parallel structure

choose(p,q)
  -- disjunction; one branch must be selected as a whole

forall(τ,f)
  where f : (x:τ) → VCPlan(S,D(x))

seq(p,q)
  where
    p : VCPlan(S,D1)
    q : Proof(Sat(S,D1)) → VCPlan(S,D2)
```

The `seq` constructor is the operational reflection of the Σ semantics.

## 11. ResidualPlan compiler

Define:

```text
VCGen(S,D)
:=
(VCList0(S,D),ResidualPlanNF(S,D)).
```

Compilation is structural and deterministic.

### Atoms

For `atom(a,b,w,c)`:

- `w ≠ req`: no mandatory residual;
- `w=req` and `c=⊤`: discharged from the P0 kernel;
- `w=req` and `c≠⊤`: emit

```text
phi :=
(⟦ c⟧_S ∧ def_S(a))⇒ def_S(b)
```

as:

```text
need(φ, λpφ. done(pack_atom_sat(pφ)))
```

### Conjunction and tensor

```text
Residual(D1 ∧ D2)  = both(Residual(D1), Residual(D2))
Residual(D1 ⊗ D2)  = both(Residual(D1), Residual(D2))
```

`WF` supplies tensor compatibility.

### Disjunction

```text
Residual(D1 ∨ D2) = choose(Residual(D1), Residual(D2))
```

The compiler does not choose a branch heuristically.

### Sequencing

```text
Residual(D1 ; D2)
  = seq(Residual(D1), λπ1. Residual(D2))
```

The second-stage plan is not opened without first-stage evidence.

### Quantification

Binder-residual mode:

```text
Residual(∀x:τ.D(x))
  = forall(τ, λx. Residual(D(x)))
```

Finite mode may deterministically expand over the enumerated domain.

### Closure

`star D` is discharged by the kernel reachability result rather than re-encoded as residual logical structure.

## 12. Residual plan canonicalization

`ResidualPlanNF` must be deterministic.

At minimum:

- flatten associative `both` nodes,
- sort commutative `both` children by canonical hash,
- deterministically order `choose` branches without deleting either,
- α-normalize binder names,
- retain sequencing order exactly,
- canonicalize proposition rendering and sort/binder context before hashing.

This makes plan shapes diffable and cacheable without altering semantics.

## 13. Obligation graph

`RunPlan` compiles a plan into either a finished proof or a structured `VCGraph`.

### 13.1 Proposition node

A `VCNode` records:

```text
id       : ObligationId
path     : ProvenancePath
ctx      : BinderContext
prop     : Prop
class    : {checkable, uncheckable, unknownYet}
deps     : Set ObligationId
onProved : Proof(prop) → Continuation
```

### 13.2 Control gates

The graph also contains non-proposition control nodes.

**SeqGate**

Stage two is unavailable until stage one yields:

```text
Proof(Sat(S,D1))
```

**ChoiceGate**

Exactly one selected branch supplies the disjunction proof. Evidence from distinct branches must not be mixed.

**ForallGate**

The binder is either:

- deterministically expanded over a finite domain, or
- retained symbolically with an explicit proof/instantiation policy.

## 14. RunPlan interpreter

`RunPlan` is pure and deterministic. It compiles; it does not invoke tools or guess proof strategies.

```text
RunPlan(S,plan)
⇒
Solved(pi)
;	ext{or};
Pending(G,Open).
```

Constructor behavior:

- `done(π)` → `Solved(π)`;
- `need(φ,k)` → obligation node carrying continuation `k`;
- `both(p,q)` → compile both and combine only after both proofs exist;
- `choose(p,q)` → compile branch structure behind a `ChoiceGate`;
- `forall(τ,f)` → finite expansion or `ForallGate`;
- `seq(p,q)` → compile `p` first; if pending, emit `SeqGate`; only after `π1` exists compile `q(π1)`.

This is the engine-level enforcement of non-collapse.

## 15. Stratified verification

Full propositions are not assumed decidable.

```text
Prop   -- full obligation language
CProp  -- explicitly checkable fragment

Extract : Prop → Option(CProp)

Verify :
  Scheme × CProp
  → sat(cert)
  | unsat(counterexample)
  | unknown(explanation)

Plan : Prop → VCPlan
```

A checker must never turn `unknown` into a proof.

### 15.1 Environment grounding

Every generated VC is interpreted in an explicit environment `Σ` containing relevant parameters, element instantiations, assumptions, and lemmas.

A distinguished environment-consistency obligation is checked first:

```text
VCEnvConsistent(Σ)
```

For this root obligation only, satisfiability is success.

For universal VCs, SMT use follows counterexample semantics:

```text
check encode(Σ) ∧ ¬encode(vc)

UNSAT => vc proven relative to Σ and the encoding
SAT   => counterexample / failure
UNKNOWN => no proof
```

Every artifact records `envHash`.

### 15.2 Element readiness

`VCInst(e)` is a kernel lookup, not an SMT problem.

Define derived readiness:

```text
VCElemReady(e)
```

meaning instantiation, type/local constraints, and predecessor readiness are proven. Higher-level obligations depend on readiness for all elements they mention.

## 16. Solver loop

The solver layer is separate from `RunPlan`.

1. Run the pure compiler/interpreter.
2. Classify open proposition nodes with `Extract`.
3. Invoke appropriate trusted/checkable backends for `CProp`.
4. On `sat(cert)`, obtain a proof term through the trusted checker boundary.
5. Feed the proof to `onProved`.
6. Splice newly unlocked downstream plan fragments into the graph.
7. Continue until solved or until a fixed point of uncheckable/unknown obligations is reached.

Search policy, branch preference, proof assistant invocation, SMT scheduling, and human interaction belong here, never in the semantic kernel.

## 17. P1 evidence-driven guard refinement

P1 activates guarded dependency edges using explicit evidence.

Define:

```text
Active(S,c) : Prop
```

and, for an evidence set `Ev`:

```text
Edge1(S,D,Ev)(a,b)
```

iff a required atom `atom(a,b,req,c)` occurs in `D` and evidence in `Ev` proves `Active(S,c)`.

Then compute:

```text
NF1(D,Ev)
=
canon(TC_on_nodes(Edge1(D,Ev),Nodes(D))).
```

A guarded atom may therefore compile as:

```text
need(Active(S,c), λpc. activate(a,b,pc); continue)
```

The solver may maintain incremental transitive closure after activation.

Required monotonicity:

```text
Evsubseteq Ev'
⇒
NF1(D,Ev)⊆ NF1(D,Ev').
```

When `Active(S,⊤)` always holds:

```text
SatStar1(S,D)⇒ SatStar0(S,D).
```

P1 is therefore an evidence-driven conservative refinement of P0.

## 18. Witnessed existential claims

Bare existential security claims are not sufficient evidence.

Reductions and simulators must be represented with explicit artifacts:

```text
VCWitnessExists(ref)
VCWitnessCorrect(ref, spec)

VCReductionWitness(witness, from, to, loss)
VCSimulatorWitness(witness, real, ideal, bound)
```

The witness reference must be pinned and content-addressed where practical.

## 19. Bounds and probabilistic composition

The default bound-composition rule is additive.

```text
ε_total ≤ Σ_i ε_i.
```

Using `max` or stronger composition requires explicit probabilistic-independence evidence.

Independence obligations record an `IndepModel` containing at least:

- adversary sharing,
- state sharing,
- parallel/sequential/adaptive composition.

All bound expressions generate well-formedness obligations, including:

```text
VCParamDefined
VCParamPositive
VCParamType
VCIsSecurityParam
VCNonZero
VCPowWellDefined
VCProbabilityRange
VCIndepValid
```

Iteration counts come from named parameters, never guessed from syntax.

## 20. Leakage and constant-time claims

Constant-time is treated as noninterference relative to an explicit observation/leakage model.

A claim has the form:

```text
VCConstTime(f, secrets, publics, LeakageModel)
```

The model records at least:

- timing granularity,
- variable-time operations,
- memory/cache observation,
- branch observation,
- speculation model,
- secret annotation discipline.

Certificates must record the exact model and tool coverage. A constant-time result outside that model is not implied.

## 21. Stable identities and provenance

Define a canonical path vocabulary:

```text
root
.left / .right
.seq1 / .seq2
.forall[x]
.need[h(prop)]
```

A VC identifier is content-addressed:

```text
VCID
=
H(
canonical(AtomVC)
∥ canonical(Origin)
∥ canonical(relevant_env_slice)
).
```

For graph nodes:

```text
id
=
H(
canonical(path)
∥ canonical(prop)
∥ canonical(ctx)
).
```

Cache keys additionally include:

- strategy hash,
- exact tool version,
- tool binary hash.

Canonical encodings must be deterministic, version-tagged, and order-independent wherever the mathematical object is unordered.

## 22. Evidence classes and claim levels

Evidence is classified explicitly:

```text
EvidenceClass :=
  Kernel
| ProofObject
| ToolRun
| HumanAttestation
```

Claims are:

```text
Proven(evidence)
Conditional(assumptions)
Claimed
```

The package must never silently promote one level into another.

## 23. Certificates

A whole-spec certificate is:

```text
Cert(S,D):=Proof(Sat(S,D)).
```

Implementations may also retain per-atom/per-VC evidence products and assemble them structurally.

A certificate bundle records:

- scheme/spec identity,
- `envHash`,
- stable VCIDs,
- kernel normalization identity,
- residual plan identity,
- evidence class per claim,
- tool name/version/binary hash and invocation metadata,
- explicit reducer/simulator references,
- security bound and bound-WF proofs,
- leakage model,
- assumptions and conditional claims,
- provenance links,
- reviewer/human-attestation metadata where applicable.

## 24. Generic proof-record integration

Dep–Proof owns cryptographic semantics. It does **not** own the generic evidence-envelope substrate.

The reusable proof-record boundary is `larsbx/finite-math-kernels/proof_records/`, which provides:

- content-addressed proof/evidence records,
- canonical record serialization,
- identity-bearing dependency edges,
- closure validation,
- typed relationship graph projection,
- evidence-vocabulary translation.

Dep–Proof may emit/consume those records, but:

- `finite-math-kernels` must not interpret `Sat`, security games, leakage models, or crypto assumptions;
- a complete proof-record closure is not itself a proof of a cryptographic proposition;
- crypto-composer remains responsible for the checker/proof semantics that justify a claim.

## 25. Trusted computing base

The TCB must be written down for every certificate profile.

At minimum:

1. the implementation of `Sat` and relevant type/kind interpretation;
2. the proof kernel or trusted proof-object checker;
3. the `CProp` verifier-to-proof bridge;
4. canonical serialization/hash routines used for identifiers;
5. compiler correctness assumptions until mechanized;
6. imported theorem trust and hypothesis checks explicitly recorded.

The central rule is:

> `Verify(S,cφ)=sat(cert)` implies `φ` only through the declared trusted checker for `CProp`; every non-checkable proposition requires a proof term, imported theorem with checked hypotheses, or explicit human-attested conditional claim.

## 26. Theorem ledger

The implementation and mechanization effort should target the following statements.

### Structural satisfaction

**T1 — compositionality.** `Sat` follows the constructors of `DepSpec`.

**T2 — scheme-upgrade monotonicity.** Under a valid scheme-state preorder and stable guards:

```text
Sat(S,D)⇒ Sat(S',D).
```

**T3 — weakening in spec strength.** For an explicitly defined spec preorder:

```text
D_1sqsubseteq D_2
⇒
Sat(S,D_2)⊢ Sat(S,D_1).
```

### Sequencing

**T4 — first projection.** A proof of `Sat(S,D1;D2)` yields a proof of `Sat(S,D1)`.

**T5 — non-collapse.** In general there is no context-free construction:

```text
Sat(S,D_1)∧ Sat(S,D_2)
	o
Sat(S,D_1;D_2).
```

**T6 — associativity up to dependent-pair isomorphism.**

**T7 — unit laws** for a neutral dependency spec `1`, if introduced.

### Closure

**T8 — reachability reflexivity.**

**T9 — propagation transitivity.**

**T10 — closure idempotence.**

**T11 — one-step edges are contained in closure.**

### Incrementality and certificates

**T12 — reachability-bounded recheck.** A localized change can only affect obligations in the dependency influence region stated by the implementation's change model.

**T13 — certificate soundness.** A well-typed certificate proves `Sat(S,D)`.

**T14 — structural certificate assembly.** Per-atom/per-subplan evidence assembles into the whole-spec proof under `WF(D)`.

**T15 — CProp verifier soundness.** A `sat` result validates the proposition through the declared trusted kernel/checker.

### Normalization

**NF-Sound.**

```text
SatStar0(S,D)
⇒
⋀ VCList0(S,D).
```

**NF-Complete.**

```text
⋀ VCList0(S,D)
⇒
SatStar0(S,D).
```

**NF-Compare.**

```text
NF0(D_1)=NF0(D_2)
⇒
⋀ VCList0(S,D_1)
⇔
⋀ VCList0(S,D_2).
```

### Well-formedness

**WF1.** `Nodes(D)` contains all atom endpoints and guard dependencies.

**WF2.** `NF0` is deterministic and α-stable under the allowed syntax equivalences.

**WF3.** Well-formed tensor operands satisfy the declared non-aliasing/resource discipline.

### P1 refinement

**P1-P0.**

```text
SatStar1(S,D)⇒ SatStar0(S,D)
```

when top guards are always active.

**P1-Monotone.**

```text
Evsubseteq Ev'
⇒ NF1(D,Ev)⊆ NF1(D,Ev').
```

### Engine

**E1 — interpreter soundness.** `RunPlan = Solved(π)` implies `π : Proof(Sat(S,D))`.

**E2 — pending-graph soundness.** Any proof assignment satisfying all open proposition nodes while respecting Seq/Choice/Forall gates deterministically reconstructs a proof of the plan goal.

**E3 — causal progress.** Newly generated obligations arise only from continuations causally downstream of discharged obligations; provenance is preserved.

## 27. Important qualification on incremental verification

“Minimal recheck set” must be parameterized by the actual change semantics.

For a pure definedness-propagation kernel, an obligation `def(a)→def(b)` can change whenever either endpoint's definedness changes. Therefore the implementation must compute the affected VC set from the set of actually changed nodes (or a formally justified influence relation), not merely from antecedent reachability.

The up-closure theorem is valid only under an explicit propagation discipline proving that changes outside that region cannot modify either endpoint of an omitted VC.

This qualification is normative: incremental optimization must not weaken verification soundness.

## 28. Categorical claims

The required categorical structure is intentionally modest.

- `DepSpec` under declared-strength inclusion forms a preorder after the chosen quotient/equivalence.
- propositions under entailment form an entailment preorder.
- stronger specifications entail weaker obligations:

```text
D_1sqsubseteq D_2
⇒
Sat(S,D_2)⊢ Sat(S,D_1).
```

No adjunction, cartesian closure, or thin-category claim is made unless the required objects, morphisms, equivalences, and hom-set correspondence are explicitly defined.

Scheme-indexed proofs naturally suggest a fibration/comprehension interpretation, but that remains an interpretation until mechanized.

## 29. Crypto-specific extension axes

The dependency kernel is domain-generic; `crypto-composer` supplies domain objects.

The security component should eventually separate:

```text
Σ_GAME  -- game kernel, worlds, oracles, win predicate
Σ_OBS   -- view/observation/leakage semantics
Σ_WIT   -- witness relation, verifier, extractor
Σ_RED   -- reductions, loss, cost, policy, composition
```

Corresponding code domains are expected to grow under:

```text
src/games/
src/observables/
src/witnesses/
src/reductions/   -- or proof/ reductions if kept together
```

These domain objects may generate DepSpec obligations; they do not replace the Dep–Proof kernel.

## 30. Initial implementation layout

The intended `crypto-composer` layout is:

```text
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

  constraints/      # existing checks become CProp backends
  schemas/          # existing CompositionGraph remains scheme-state/data-flow IR
  types/
  catalog/
  emit/
```

The existing `CompositionGraph` is retained. It models actual cryptographic/data-flow structure; Dep–Proof models what must be supplied/proved about a scheme and how those proofs depend on one another.

## 31. Mechanization plan

The first proof-assistant slice should be intentionally small:

1. finite `Elem`,
2. `Atom`, `DepSpec` without rich crypto contracts,
3. `inst`/definedness,
4. inductive `Reach`,
5. `ReqEdges0`, `Nodes`, `NF0`,
6. `SatStar0`,
7. `NF0_sound` and `NF0_complete`,
8. `WF1` and deterministic normalization lemmas,
9. `VCPlan` sequencing fragment,
10. `RunPlan` soundness for `done/need/both/seq`.

Disjunction, binders, P1, richer evidence classes, and crypto-specific propositions should be layered only after the core correspondence is stable.

## 32. Non-goals

Dep–Proof does not:

- decide arbitrary cryptographic propositions,
- infer that an empirical result is a theorem,
- infer probabilistic independence,
- infer a reduction witness from an implication label,
- claim standard-model security from ROM/QROM evidence without a concrete bridge theorem,
- flatten quantified or branching obligations into a semantically weaker list,
- make `finite-math-kernels` responsible for crypto semantics,
- replace the existing composition/data-flow graph.

## 33. Acceptance criteria for the first implementation slice

A first implementation is conforming only when:

1. the arrow convention is enforced in code/docs/tests;
2. `Sat` is scheme-indexed;
3. sequencing cannot be represented as plain conjunction;
4. `WF`, `Nodes`, `ReqEdges0`, `Reach`, `NF0`, and `VCList0` are deterministic;
5. normalization fixtures prove stable ordering and closure behavior;
6. guarded atoms remain residual unless explicitly activated;
7. `ResidualPlan` preserves `∨`, `∀`, and `;`;
8. `RunPlan` delays sequence stage two until first-stage evidence exists;
9. `unknown` never becomes a proof;
10. stable identifiers include environment/provenance context;
11. evidence imported from `finite-math-kernels/proof_records` is treated as evidence metadata, not as an automatic proof of `Sat`;
12. tests cover a negative case for every semantic invariant introduced.
