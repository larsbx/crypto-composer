# crypto-composer v0.1 (spec-aligned skeleton)

This repo is the *minimum viable* implementation scaffold for the composition-graph + constraint-checker design.

## What’s implemented (v0.1)
- Layer 0–4 core types (EntropyClass w/ entails + ctx compatibility)
- Typed refs: `Ref`, `ValueRef`, `ValueSource`
- Graph primitives: `KemOp`, `KDFCall`, `AeadOp`, `CompositionGraph`
- Schema expansions:
  - `HybridKEM` (encap + decap variants)
  - `KEMDEM` (seal + open variants; message-scoped nonce derivation)
- Constraints:
  - C1 EntropyFlow
  - C2 DomainSep
  - C3 NonceDiscipline
  - C4 FailureConsistency (branch-aware reachability, conservative may-reach)
  - C5 ConstantTimeChain (simple secret-path timing check)
  - C6 KeyCommitment (product requirement check)
  - W1 AssumptionDiversity (advisory)

## TODOs (intentionally left everywhere)
This repo is deliberately sprinkled with `// TODO(v0.2+)` markers for next increments:
- WireFormat (TLS/HPKE/COSE)
- More precise entropy semantics for public values (currently `Uniform(0)` placeholder)
- Better reachability (branch refinement + op-level semantics)
- Proof artifact AST + YAML/JSON emission polish
- CLI command parsing (currently minimal)

## Quickstart (local)
1. Install Zig (0.12+ recommended).
2. From repo root:
   - `zig test test/all_tests.zig`
   - `zig build` (optional; stub build file included)

