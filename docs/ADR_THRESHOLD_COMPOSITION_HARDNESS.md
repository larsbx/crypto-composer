# ADR — TclMesh Threshold Composition and Typed Hardness Evidence

**Status:** Architectural direction accepted for documentation, not implementation/security acceptance  
**Date:** 2026-11-01  
**Domain owner:** crypto-composer  
**Runtime consumer:** [TclMesh issue #36](https://github.com/larsbx/tclmesh/issues/36)  
**Related:** [Dep–Proof PR #1](https://github.com/larsbx/crypto-composer/pull/1), [toolchain PR #2](https://github.com/larsbx/crypto-composer/pull/2), [TclMesh fail-closed PR #37](https://github.com/larsbx/tclmesh/pull/37), [source preflight PR #40](https://github.com/larsbx/tclmesh/pull/40).

This ADR records the cross-repository review and the proposed categorical hardness taxonomy. Its existence or merge **does not** enable cryptographic threshold release, implement Dep–Proof, certify any algorithm, or resolve the underlying TclMesh issue.

## 1. Authority and existing foundations

| Owner | Authority | Must not be inferred |
| --- | --- | --- |
| **crypto-composer** | Cryptographic domain contracts, scheme state, typed composition, security obligations and certificate acceptance rules | That an unproved contract is cryptographically sound |
| **TclMesh** | Authenticated participants, backend execution, independent key custody, verified shares, durable combination, recipient-only release | That a signature/approval token is a partial decryption |
| **finite-math-kernels/kernel/proof_records** | Generic evidence identity, canonical provenance and typed dependencies | Cryptographic truth from provenance alone |
| **semantic-categorical-oracle** (optional) | Explicitly registered structural semantics and conformance vectors | Cryptographic proof, effect authorization, release |
| **Halaqa / Senad+** (possible transport) | Signed envelopes/transcript references | Correctness of cryptographic partial shares |

Current main contains `CompositionGraph` with values, operations, dataflow, success/failure paths and public/private outputs; `KEMContract`, `KDFContract` and `AEADContract`; and C1–C6 checks for entropy, KDF label separation, nonce discipline, failure reachability, **advisory** timing and **shallow** key commitment. Those checkers do **not** establish key-share correctness, a no-full-key custody guarantee, or authenticated threshold combination. `test/harness.zig` demands rationale via `requireProof`; that metadata is **not** a machine-checked proof.

Dep–Proof in PR #1 remains a **proposed** design (with unresolved conjunction merge-law and rich-obligation monotonicity review findings); PR #2 is a separate pending Zig toolchain repair. Do not describe either as merged, executable, or CI-accepted solely because this ADR records its intent.

## 2. Proposed threshold scheme contract

A threshold FHE protocol is **not** an ordinary KEM decapsulation or an authorization quorum. Introduce a distinct, explicitly evidence-dependent contract:

```text
ThresholdSchemeContract {
  scheme_id, source_revision, binary_digest, implementation_version,
  parameter_profile, encoding_version, keyset_id, epoch,
  participants: n, release_quorum: q_release,
  privacy_corruption_bound: f_priv,
  byzantine_or_offline_fault_bound: f_byz,
  client_response_count: r_output,
  supported_participant_subsets, independent_custody_model,
  partial_verification_model, authenticated_combination_model,
  recipient_delivery_model, security_claim_refs, evidence_refs, proof_refs
}
```

The numbers denote **different things**. A claimed any-`q_release`-of-`n` secrecy boundary requires a reviewed secrecy guarantee for coalitions of up to `q_release-1` and successful reconstruction with every **scheme-supported** `q_release` subset. Necessary numerical checks include `q_release - 1 <= f_priv` and, where output reconstruction is claimed from any `q_release` participants, `r_output <= q_release`. Passing these checks cannot prove the protocol or its implementation.

The documented four-party Zama KMS example's one-party corruption bound and three client reconstruction responses **do not establish 3-of-4 collusion resistance**. Treat its source/parameter compatibility as pending until the **exact pinned** source is authenticated. Never silently substitute a different revision or turn `authorization-quorum` into `cryptographic-threshold-decryption`.

### Proposed typed protocol graph (not yet implemented)

| Proposed operation | Input → output | Mandatory obligation |
| --- | --- | --- |
| `DistributedKeygen` / `KeyEpoch` | Independent custodians → protected key shares and public verification material | No evaluator-held full decryption key; immutable keyset/epoch |
| `BindReleaseRequest` | Manifest/policy, ciphertext/circuit/output, purpose, nonce/expiry and recipient → canonical bytes | Versioned domain separation; exact authenticated request binding |
| `PartialDecrypt` | Custodian-local share + request → **untrusted** partial/proof | Share and plaintext never exposed to evaluator/kernel/logs |
| `VerifyPartial` | Partial, participant material and cryptographic proof / malicious-secure MPC evidence → backend-owned **verified reference** | Actual correctness verified **before counting**, not signature-only |
| `CountVerified` | Bound verified references → distinct active-holder quorum | Atomic deduplication, replay prevention, revocation and scope checking |
| `CombineVerified` | Scheme-supported verified subset → authenticated result | No fallback to ordinary full-key `decrypt` |
| `RecipientDeliver` | Result + frozen authorized recipient → protected delivery | Plaintext never enters unauthorized kernel/operator view |
| `ReleaseReceipt` | Durable completed release → nonsecret audit evidence | Fail-closed crash/retry and no share logging |

`UntrustedPartial` and `VerifiedPartial(binding, holder, keyset, epoch, ciphertext, output)` are **different types**. Callers cannot self-assert verification. An approval/signature alone cannot be promoted into a verified partial. An authorization-only graph remains separate.

Negative controls must cover `q-1` refusal, every permitted `q` subset, invalid-but-signed partials, forged proofs, duplicates, mixed bindings, stale keys/holders, replay, crash/recovery, unauthorized recipient, incorrect final output and a full-key-fallback mutant. Existing C2 label uniqueness, C4 conservative reachability and C5 warning-only timing analysis are **not sufficient**; introduce hard-failing threshold constraints plus native cryptographic tests.

## 3. Hardness as a typed reduction-relative structure

The proposed computational-hardness taxonomy is **multidimensional**, not a numerical easy-to-hard ladder:

```text
HardnessDescriptor {
  problem_kind,           // decision, search, counting, optimization, ...
  input_output_types,
  computational_model,    // probabilistic classical, quantum, interactive, ...
  resource_policy,        // concrete/asymptotic time, space, queries, communication
  reduction_kind,         // many-one, oracle, distributional, parameterized, ...
  instance_regime,        // worst-case, average-case, explicit distribution
  parameterization,       // security parameter, field/characteristic, representation
  claim_status,           // Proven, Conditional, Conjectured, Empirical, Pending
  assumptions, reduction_refs, theorem_refs, provenance
}
```

A typed reduction `A → B` carries an actual transformation, preservation obligations, resource map and security/advantage loss. The arrow direction and attack model matter. Reductions between decision, search, counting, parameterized, approximation and distributional tasks are **not interchangeable**. Classical worst-case NP-hardness, finite-field polynomial degree, or a category-theoretic degree **does not imply average-case or post-quantum cryptographic security**.

Where many-one reductions between languages compose, they form a category. Mutual reducibility yields a preorder quotient of degrees; this **thin quotient** is distinct from the original proof-carrying reduction category. A scheme's proof must retain the richer reduction type, distributions, adversary costs and losses. Non-default security-bound composition (particularly a `max` bound) requires an explicit theorem-bearing `ComposeLaw`, not a bare appeal to independence.

Problem types may be generated from one relation by existential decision, search, counting, optimization, etc.; they need separate computational judgments. A categorical hardness calculus and resource-enriched diagram complexity are **research directions**, not existing implemented features of crypto-composer. For algebraic assumptions, include finite field, characteristic, operation set, circuit size/depth and representation to avoid confusing algebraic and cryptographic hardness. Do not import unverified topical claims as formal axioms.

### Epistemic status firewall

| Status | Meaning |
| --- | --- |
| `Proven` | Kernel/TCB-accepted proof of **exact** proposition under pinned definitions |
| `Conditional` | Explicit hypotheses and side conditions are still attached to a valid implication |
| `Claimed/Conjectured` | Proposed claim without proof |
| `Empirical` | Tests or benchmarks, not unconditional lower bounds |
| `Pending/Unknown` | Missing, inaccessible or incomplete evidence; **no proof** |

A passing test, provenance hash, signed approval, explanatory `requireProof` text, numerical threshold condition, solver `unknown`, or proof-record closure **never** automatically becomes a cryptographic `ProofCertificate`. It may remain in an `EvidenceBundle`. This follows the intended separation in Dep–Proof PR #1, whose proposed `Requires` and `Derives` edges, `StageResult`, control-local `VCPlan`, `RunPlan` and `CProp` reflection must first be implemented and validated.

For TclMesh, the dependency chain is proposed as:

```text
Authenticated source/protocol
  → threat model and proven parameter profile
  → distributed key custody
  → cryptographic partial verification
  → distinct verified quorum
  → authenticated combination
  → recipient-bound release
```

Stage-two evidence cannot be used before stage one's proof-dependent output; control branches may not pool incompatible witnesses. A pending stage keeps downstream conclusions conditional/pending, never accepted.

## 4. Implementation and acceptance sequence

1. Resolve Crypto-Composer PR #2's actual Zig/CI gate and PR #1's two outstanding semantic issues. Neither is merged by this ADR.
2. Add `ThresholdSchemeContract` **under red-first, proof-associated tests**, as a descriptive contract that cannot enable release.
3. Extend `CompositionGraph` with explicit protocol steps, `UntrustedPartial` versus `VerifiedPartial`, recipient-only output and hard-failing correctness/binding constraints.
4. Implement Dep–Proof obligations with accurate `Requires`/`Derives` semantics, stage-indexed transitions, kernel-checked proof bridges, typed reduction loss, and non-promotion of conditional evidence.
5. Use finite-math-kernels for generic evidence identities without delegating crypto claim truth; optionally register structural oracles only for proved-scope semantics.
6. Only after a pinned and independently reviewed native threshold scheme satisfies TclMesh issue #36, integrate the runtime backend and validate all negative controls, independent custody, supported subset coverage and recipient semantics.

**ADR acceptance is documentary only:** merging it records the architecture and these caveats. It must not assert working threshold DKG, correct decryption shares, compatible KMS source, formal proof calculus, or production cryptographic conformance.
