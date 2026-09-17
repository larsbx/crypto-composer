<!--
Derived from templates/docs/CONTRIBUTING.md in larsbx/agent-icm @ sha256:88bf9172c22bc8da
Edit the canonical template or estate.toml, then re-render: make estate
Hand-edits here are drift and `make estate-check` fails on them.
-->

# Contributing to crypto-composer

Composition graphs for cryptographic primitives, with constraints C1-C6
checked at build time.

**Language / toolchain:** Zig 0.13
**CI:** GitHub Actions (`.github/workflows/ci.yml`) on ubuntu, macos and windows; runs `make ci`

Read these first — they are normative, not background:

- `AGENTS.md`
- `README.md`
- `docs/QUICKSTART.md`

---

## The gates

Run these before you open a pull request. Paste what they said into the PR's
evidence table.

1. the whole gate, as CI runs it —

   ```sh
   make ci
   ```

2. suite, including negative constraint cases —

   ```sh
   make test
   ```

3. formatting —

   ```sh
   make fmt-check
   ```

4. integrity of tracked files —

   ```sh
   make verify-manifest
   ```

5. no red ledger entries remain —

   ```sh
   make tdd-green
   ```

A check you did not run is not evidence. Say which ones you skipped and why;
the pull request template has a place for exactly that.

## What counts as evidence here

- TDD/PDD is required, not encouraged: the failing test goes into
  `test/all_tests.zig` before the implementation.
- Every test calls the harness `requireProof` with a non-empty statement and
  argument. A test without a proof is not coverage.
- Red -> green transitions are recorded in `tdd_ledger.zig`. A change does not
  finish with an entry still red.
- `MANIFEST.SHA256` is regenerated (`make manifest`) whenever tracked files
  change, or the integrity check stops meaning anything.
- Cryptographic assumptions are documented in `src/types/assumptions.zig`; an
  unchecked assumption is a bug.

## Standing prohibitions

- Never write implementation before the failing test.
- Never land a test with no `requireProof`.
- Never finish with a red `tdd_ledger.zig` entry.
- Never replace a crucial design element (constraints, contracts, graph
  semantics) without the double-check: a focused regression test plus a short
  rationale note.
- Never skip a validation path because it is unlikely. Model the divergence
  instead.

These are not style preferences. Each one is settled somewhere in the documents
above; changing one is a decision record, not a pull request comment.

## Working shape

1. **Branch** from the default branch.
2. **Make the failing case first** where this repository's discipline requires
   it, and in every case make sure the new test fails without your change.
3. **Run the gates.** All of them, or name the ones you did not.
4. **Update the surfaces.** Documentation, status tables, ledgers and generated
   artifacts that name the behaviour you changed are part of the change, not a
   follow-up. Regenerate generated files with their tooling; never hand-edit one.
5. **Open the pull request** using the template. Fill in *What this does not
   establish* — it is required, and it is the section reviewers read first.

## Claim discipline

State exactly what your change establishes and no more.

- A search that stopped at a limit reports where it stopped.
- A bounded failure is not an absence.
- A refusal is not a clean answer.
- A translation preserves or lowers authority; it never raises it.
- "Verified" unqualified is not a claim. Say verified *by what*.

## Commits

Imperative, present tense, describing the difference: `Add the M-adic ball
carrier`, `Reject a singular M before the zeroth power`. The body carries the
reasoning when the subject cannot.
