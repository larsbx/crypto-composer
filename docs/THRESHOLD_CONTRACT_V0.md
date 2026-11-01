# ThresholdSchemeContract v0 — inert declarative gate

**Status:** first executable *necessary-condition* checker, not cryptographic
verification, acceptance, or a TclMesh backend. Tracks
[TclMesh #36](https://github.com/larsbx/tclmesh/issues/36) and
[ADR_THRESHOLD_COMPOSITION_HARDNESS.md](ADR_THRESHOLD_COMPOSITION_HARDNESS.md).

## Scope and authority

`src/types/threshold.zig` exposes `Contract.checkNecessary()` and
`Contract.assess()`. Unlike the ordinary KEM catalog, threshold
decryption requires independently held shares, a partial-correctness
verifier or reviewed malicious-secure MPC, and an authenticated
combination protocol. **None is implemented by this PR.** The module
has no cryptographic primitives, runtime APIs, or release-enabling
functions.

It is deliberately independent from `src/constraints/checker.zig` and
`src/schemas/graph.zig`. A later change must add actual protocol graph
operations with a proof/refinement boundary; a claimed `Contract`
must never be used as a capability flag.

## Claim fields and necessary conditions

The caller supplies **untrusted** scheme/version/parameter/source identity,
a purported SHA-256 digest, and distinct parameters:

- `participants=n`: number of custodians;
- `release_quorum=q`: claimed cryptographic reconstruction threshold;
- `privacy_corruptions=f_priv`: claimed confidentiality bound;
- `byzantine_faults=f_byz`: separately claimed fault bound;
- `client_responses=r_output`: required client-side responses.

The gate checks `1<=q<=n`, `0<=f_priv<n`, `0<=f_byz<n`,
`1<=r_output<=q`, and the **necessary** secrecy relation
`q-1<=f_priv`. There is deliberately *no* rule that promotes
`f_byz` or `r_output` into `f_priv`. The published KMS four-party
example (`n=4, f_priv=1, r_output=3`) cannot substantiate a
3-of-4 privacy claim: for any `q`, either `q<=2` violates
`r_output<=q` or `q>=3` violates `q-1<=f_priv`. This is
**not** an exploit or universal impossibility proof.

The contract also rejects claiming any-q release with only a fixed
custodian group, evaluator-held full key, signatures alone, kernel
plaintext delivery, or fail-open recovery. Its `*_claimed` enum
values are *unverified assertions*, not trusted evidence. Unknown and
explicitly unsafe custody/delivery are distinct rejection errors.

A successful `checkNecessary()` only establishes **no contradiction
among the declared fields**. `assess()` has precisely two outcomes:
`rejected(error)` or `pending_evidence(obligations)`. There is no
`accepted`, `verified`, `ready`, or `authorize` result.

## Mandatory evidence before any runtime threshold integration

Every passing contract retains pending obligations:

1. Exact authenticated source and binary;
2. Audited security model and parameter profile;
3. Proof of actual privacy/corruption bound;
4. Every supported `q`-subset correct and available;
5. No complete secret key at evaluator, including backup/recovery;
6. Scheme-verified partials or complete malicious-secure MPC transcript;
7. Authenticated combination without ordinary decrypt fallback;
8. Frozen, canonical domain-separated request/ciphertext/epoch/recipient binding;
9. Durable deduplication, replay/revocation/crash fencing;
10. Recipient-only or explicitly authorized public output and leakage accounting.

A provider signature, externally supplied `verified` flag, source hash,
TclMesh authorization quorum or a green unit test is *never* sufficient.

## Development and checks

Following `AGENTS.md` PDD, the first commit
`c0ad5999f1263c6cc572cefac0da087e2c57c55a`
added failing (missing-module) contract cases in `test/all_tests.zig`
**before** the implementation. These tests include explicit proof
statements and arguments using `test/harness.zig`; they are
documentary test rationales, not machine-checked proofs. Positive
cases are explicitly only `pending_evidence`, never conformance.

Run:

```sh
make test
make ci
```

**Known independent baseline impediments:** main's legacy
`MANIFEST.SHA256` lists large numbers of untracked generated build
files that do not exist in a clean checkout, and the existing workflow
still uses Zig 0.13 against newer build API (toolchain PR #2 is open).
Do not claim full CI is green unless a verified exact-head run
establishes it. The manifest should be independently repaired using
tracked-file-only enumeration; do not substitute a subset manifest
and call it a full-project integrity check.

**Next change:** implement a *typed* `UntrustedPartial` →
`VerifiedPartial` protocol graph and hard-failing checker under
independent cryptographic evidence, not under this inert contract.
