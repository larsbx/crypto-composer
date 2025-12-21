# crypto-composer v0.1 (spec-aligned skeleton)

crypto-composer builds composition graphs for cryptographic constructions and validates them with explicit constraints. The core output is a `CompositionGraph` that records values, operations, and data-flow edges. The checker enforces entropy flow, domain separation, nonce discipline, failure consistency, timing chains, and key commitment.

## Codebase overview
- `src/types/`: entropy accounting, contracts, and shared types.
- `src/catalog/`: primitive registries (KEM/KDF/AEAD) and their contracts.
- `src/schemas/`: schema expansions that build `CompositionGraph` instances.
- `src/constraints/`: C1-C6 checks plus advisory warnings.
- `src/emit/`: artifact and vector scaffolding.
- `test/`: proof-driven tests and constraint fixtures (see `test/harness.zig`).
- `constraint-test-generator.zig`: generates proof-bound constraint test stubs.

## How it fits together
1. A schema expansion builds a `CompositionGraph` from catalog primitives.
2. The checker walks the graph and emits constraint findings.
3. Tests assert on those findings and require a proof statement to justify why the test exists.

## What's implemented (v0.1)
- Layer 0-4 core types (EntropyClass w/ entails + ctx compatibility)
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
- Proof-driven test harness + constraint test generator

## TODOs (intentionally left everywhere)
This repo is deliberately sprinkled with `// TODO(v0.2+)` markers for next increments:
- WireFormat (TLS/HPKE/COSE)
- More precise entropy semantics for public values (currently `Uniform(0)` placeholder)
- Better reachability (branch refinement + op-level semantics)
- Proof artifact AST + YAML/JSON emission polish
- CLI command parsing (currently minimal)

## Quickstart (local)
1. Install Zig (>= 0.13) and Python 3.
2. From the repo root:
   - `make test`
   - `make ci`
   - `make manifest`
