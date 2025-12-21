#!/usr/bin/env python3
"""Generate MANIFEST.SHA256 for the project directory.

We hash *files* under the repo root, excluding build artifacts and the manifest itself.

TODO(v0.2+):
  - Use `git ls-files` when running in a git checkout.
  - Add support for SHA-512.
  - Add signed manifest (minisign/sigstore).
"""
from __future__ import annotations

import hashlib
import os
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]
OUT = REPO_ROOT / "MANIFEST.SHA256"

EXCLUDE_DIRS = {".git", ".zig-cache", "zig-out"}
EXCLUDE_FILES = {"MANIFEST.SHA256"}

def iter_files(root: Path):
    for p in sorted(root.rglob("*")):
        if p.is_dir():
            continue
        rel = p.relative_to(root)
        parts = rel.parts
        if parts and parts[0] in EXCLUDE_DIRS:
            continue
        if rel.name in EXCLUDE_FILES:
            continue
        yield p, rel

def sha256_file(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()

def main() -> int:
    lines = []
    for p, rel in iter_files(REPO_ROOT):
        digest = sha256_file(p)
        # Format: "<hex>  <path>" (two spaces) compatible with sha256sum -c
        lines.append(f"{digest}  {rel.as_posix()}")
    OUT.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"Wrote {OUT} with {len(lines)} entries")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
