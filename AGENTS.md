# Repository Guidelines

## Project Structure & Module Organization
- Core Zig code lives in `src/`, split by responsibility: `types/` (entropy, contracts), `schemas/` (composition graphs such as `hybrid_kem.zig` and `kem_dem.zig`), `constraints/` (C1–C6 checks), `catalog/` (primitive registries), and `emit/` (artifact/vectors scaffolding). Entry points are `src/main.zig` and `src/lib.zig`.
- Tests are in `test/all_tests.zig`; add new suites there rather than scattering fixtures.
- Docs sit in `docs/` (see `docs/QUICKSTART.md` for a walkthrough). Build scripts and helpers are in the top-level `Makefile` and `scripts/`.

## Build, Test, and Development Commands
- `make test` (or `zig build test`): compile and run the full suite, including negative constraint cases.
- `make ci`: format check, tests, and manifest verification; mirrors GitHub Actions expectations.
- `make fmt` / `make fmt-check`: run Zig formatter locally or verify formatting by diffing.
- `make manifest` / `make verify-manifest`: regenerate or check `MANIFEST.SHA256` using the Python helpers.
- `make build`: plain `zig build` if you need a binary artifact.

## Coding Style & Naming Conventions
- Use Zig 0.12+ style: `zig fmt` is the source of truth; avoid hand-formatting divergences.
- Favor small, total functions; keep constraint logic explicit with descriptive names (`checkEntropyFlow`, `validateNonceDiscipline`).
- File naming is snake_case; types and structs are PascalCase; functions/fields use lowerCamelCase.
- Prefer `// TODO(v0.2+)` markers already in use for incremental work.

## Testing Guidelines
- Add positive and negative paths to `test/all_tests.zig`; test names should describe the invariant being guarded (e.g., `test "nonce must be unique per message"`).
- When adding a new primitive or schema, write a failing composition graph first, then a valid one to prove coverage.
- Run `make test` before submitting; if adding constraints, consider edge cases around reachability and timing paths.

## TDD/PDD Workflow (Required)
- No work without a failing test: add the failing test in `test/all_tests.zig` before changing implementation code.
- No test without proof: every test must call the harness `requireProof` with a non-empty statement + argument (PDD = Proof-Driven Development).
- Use the shared harness in `test/harness.zig` for proof validation and common assertions; import it as `const harness = @import("harness.zig");`.
- For constraint changes, include both the failing graph and a passing counterpart that demonstrates the fix.

## Commit & Pull Request Guidelines
- Commit messages: imperative, present-tense subject lines (`Add KEM catalog entry`, `Fix nonce discipline check`) with concise detail in the body when needed.
- PRs should: state the behavior change, link related issues/spec items, summarize test coverage (`make test`, `make ci`), and include notes on new constraints or assumptions introduced.
- Include example graphs or failing cases in the PR description when they help reviewers reason about correctness.

## Security & Configuration Tips
- Document every cryptographic assumption you rely on inside `src/types/assumptions.zig` or adjacent modules; unchecked assumptions should be treated as bugs.
- Keep failure modes explicit—if a path can diverge, model it rather than skipping validation.
- Regenerate and verify `MANIFEST.SHA256` (`make manifest` / `make verify-manifest`) when adding tracked files to ensure integrity checks stay meaningful.
