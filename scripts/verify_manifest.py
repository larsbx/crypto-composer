#!/usr/bin/env python3
"""Verify MANIFEST.SHA256.

Exits non-zero if any file hash mismatches or referenced files are missing.

TODO(v0.2+): make error output nicer; support ignoring extra files.
"""
from __future__ import annotations

import hashlib
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]
MANIFEST = REPO_ROOT / "MANIFEST.SHA256"

def sha256_file(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()

def main() -> int:
    if not MANIFEST.exists():
        print("MANIFEST.SHA256 not found. Run: python3 scripts/make_manifest.py")
        return 2

    ok = True
    lines = MANIFEST.read_text(encoding="utf-8").splitlines()
    for i, line in enumerate(lines, start=1):
        if not line.strip():
            continue
        try:
            expected, rel = line.split("  ", 1)
        except ValueError:
            print(f"Malformed line {i}: {line!r}")
            ok = False
            continue

        path = (REPO_ROOT / rel).resolve()
        if not path.exists():
            print(f"Missing file: {rel}")
            ok = False
            continue

        actual = sha256_file(path)
        if actual.lower() != expected.lower():
            print(f"Hash mismatch: {rel}")
            print(f"  expected: {expected}")
            print(f"  actual:   {actual}")
            ok = False

    if ok:
        print("MANIFEST.SHA256 verified OK")
        return 0
    return 1

if __name__ == "__main__":
    raise SystemExit(main())
