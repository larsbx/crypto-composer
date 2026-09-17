<!--
Derived from templates/records/TDD_LEDGER_RECORD.md in larsbx/agent-icm @ sha256:f14e6b0b2ea50eec
Edit the canonical template or estate.toml, then re-render: make estate
Hand-edits here are drift and `make estate-check` fails on them.
-->

# TDD/PDD ledger record — `<invariant being guarded>`

<!--
Red first, then green. This record exists so the transition is auditable after
the fact, when both runs are gone and only the diff remains.
-->

- **Entry id:** `<as it appears in the ledger>`
- **Invariant:** `<what must always hold, stated as a property>`
- **Test:** `<file and test name — the name describes the invariant, not the function>`

## Red

- **Commit:** `<sha of the failing state>`
- **Command:**
- **Output:**

```text
<!-- The failure. The actual assertion that fired, not a summary of it. -->
```

- **Why it fails for the right reason:** <a test that fails because of a typo proves nothing>

## Green

- **Commit:** <sha>
- **Command:**
- **Output:**

```text
```

## Proof obligation

<!--
The statement and argument passed to the proof harness. A test without a proof
is not coverage: it asserts that today's behaviour is today's behaviour.
-->

- **Statement:**
- **Argument:**

## Negative path

<!--
The counterpart that must still fail. For a constraint change: the graph that
is now rejected, beside the one that is now accepted.
-->

## Ledger state

- [ ] No entry left red.
