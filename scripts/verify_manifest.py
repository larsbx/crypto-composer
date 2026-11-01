#!/usr/bin/env python3
"""Verify MANIFEST.SHA256 covers every tracked source, not untracked caches.

Uses committed Git blob bytes, so a clean Windows CRLF checkout agrees with
Linux/macOS. This is an integrity/consistency check, not a signed supply-chain
attestation or a cryptographic proof of source correctness.
"""
from __future__ import annotations

import hashlib
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[1]
MANIFEST_NAME = "MANIFEST.SHA256"
MANIFEST = ROOT / MANIFEST_NAME


def git_bytes(*args: str) -> bytes:
    return subprocess.run(
        ["git", "-C", str(ROOT), *args],
        check=True, capture_output=True,
    ).stdout


def expected_records() -> list[str]:
    paths = sorted(
        raw.decode("utf-8")
        for raw in git_bytes("ls-tree", "-rz", "--name-only", "HEAD").split(b"\0")
        if raw and raw.decode("utf-8") != MANIFEST_NAME
    )
    return [
        f"{hashlib.sha256(git_bytes('show', 'HEAD:' + path)).hexdigest()}  {path}"
        for path in paths
    ]


def main() -> int:
    if not MANIFEST.is_file():
        print("MANIFEST.SHA256 not found. Stage source changes and regenerate it.")
        return 2

    # Git normalizes platform-native line endings according to repository
    # attributes; don't hash the CRLF-expanded Windows worktree bytes.
    actual = MANIFEST.read_text(encoding="utf-8").splitlines()
    expected = expected_records()

    if actual != expected:
        got = set(actual)
        want = set(expected)
        for entry in expected:
            if entry not in got:
                print(f"Missing/outdated tracked entry: {entry}")
        for entry in actual:
            if entry not in want:
                print(f"Unexpected/stale manifest entry: {entry}")
        if len(actual) != len(set(actual)):
            print("Duplicate entries in manifest")
        return 1

    # Detect changed tracked source as distinct from hash-record consistency.
    # Git's own content-filter semantics handle CRLF checkout normalization.
    diff = subprocess.run(
        ["git", "-C", str(ROOT), "diff", "--quiet", "--exit-code", "HEAD", "--"],
        check=False,
    )
    if diff.returncode != 0:
        print("Tracked working tree differs from the checked manifest commit")
        return 1

    print(f"MANIFEST.SHA256 verified OK ({len(expected)} committed source files)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
