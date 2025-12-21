docs/QUICKSTART.md
# Quickstart

---

## 1. Install Prerequisites

### Zig
Install Zig ≥ 0.13:

```bash
zig version

Python

Python 3 is required for hash manifest tooling:

python3 --version

2. Build and Test

From the repo root:

make test


This runs:

graph expansion tests

negative constraint tests

schema invariants

3. Run the Full CI Locally
make ci


Equivalent to GitHub Actions:

formatting check

tests

manifest verification

4. Verify Integrity

To regenerate the hash manifest:

make manifest


To verify all tracked files:

make verify-manifest


This ensures no file drift.

5. What to Read First

If you want to understand the system:

src/types/ground.zig — entropy, context, failure modes

src/schemas/hybrid_kem.zig — minimal composition

src/schemas/kem_dem.zig — nonce + AEAD discipline

src/constraints/ — why invalid constructions fail

6. Adding a New Primitive (Example)

Add contract to src/catalog/

Ensure compile-time invariants hold

Re-run:

make test


Invalid contracts should fail at compile time.

7. Adding a New Schema

Define expansion in src/schemas/

Produce a CompositionGraph

Let existing constraints apply automatically

Add negative tests

If you need a new constraint, add it explicitly.

Philosophy

If a cryptographic assumption is important, it must be written down.
If a failure path exists, it must be modeled.
If a nonce can be reused, the checker should scream.

This tool exists to make those failures impossible to ignore.

TODO (Quickstart)

TODO(v0.2): CLI walkthrough

TODO(v0.2): Example artifact output

TODO(v0.3): Visualization of graphs
