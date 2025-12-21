# Quickstart

## Prerequisites
- Zig >= 0.13
- Python 3 (manifest tooling)

```bash
zig version
python3 --version
```

## Build and test
```bash
make test
```

This runs:
- graph expansion tests
- negative constraint tests
- schema invariants

## Run the full CI locally
```bash
make ci
```

Equivalent to:
- formatting check
- tests
- manifest verification

## Verify integrity
```bash
make manifest
make verify-manifest
```

## Codebase tour
- `src/types/`: entropy, contracts, assumptions.
- `src/catalog/`: primitive registries and contracts.
- `src/schemas/`: schema expansions (`hybrid_kem`, `kem_dem`).
- `src/constraints/`: C1-C6 checks and W1 advisory warning.
- `src/emit/`: artifact and vector scaffolding.
- `test/`: proof-driven tests and constraint fixtures.
- `constraint-test-generator.zig`: generates proof-bound constraint test stubs.

## How the checker works
1. A schema expansion constructs a `CompositionGraph`.
2. Constraint checks traverse values, ops, and edges to report violations.
3. Tests assert on those violations and require a proof statement before they run.

## What to read first
- `src/types/ground.zig`: entropy, context, failure modes.
- `src/schemas/hybrid_kem.zig`: minimal composition expansion.
- `src/schemas/kem_dem.zig`: nonce + AEAD discipline.
- `src/constraints/`: why invalid constructions fail.

## Adding a new primitive (example)
1. Add a contract in `src/catalog/`.
2. Document assumptions in `src/types/assumptions.zig`.
3. Add tests with proofs in `test/all_tests.zig`.
4. Run `make test`.

Invalid contracts should fail at compile time.

## Adding a new schema
1. Define expansion in `src/schemas/`.
2. Produce a `CompositionGraph`.
3. Let existing constraints apply automatically.
4. Add negative and positive tests with proofs.

If you need a new constraint, add it explicitly.

## Philosophy
If a cryptographic assumption is important, it must be written down.
If a failure path exists, it must be modeled.
If a nonce can be reused, the checker should scream.

This tool exists to make those failures impossible to ignore.

## TODO (Quickstart)
- TODO(v0.2): CLI walkthrough
- TODO(v0.2): Example artifact output
- TODO(v0.3): Visualization of graphs
