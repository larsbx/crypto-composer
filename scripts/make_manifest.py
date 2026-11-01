#!/usr/bin/env python3
"""Generate MANIFEST.SHA256 from Git's tracked index, not local build caches.

Stage source changes with git add before running this generator. The generated
manifest is then staged and committed in the same Git commit as the files it
describes. Hashes are of Git-index blob bytes (portable across CRLF worktrees).
"""
from __future__ import annotations

import hashlib
from pathlib import Path
import subprocess

REPO_ROOT = Path(__file__).resolve().parents[1]
MANIFEST_NAME = "MANIFEST.SHA256"
OUT = REPO_ROOT / MANIFEST_NAME


def git_bytes(*args: str) -> bytes:
    return subprocess.run(
        ["git", "-C", str(REPO_ROOT), *args],
        check=True, capture_output=True,
    ).stdout


def tracked_paths() -> list[str]:
    paths = [
        raw.decode("utf-8")
        for raw in git_bytes("ls-files", "--cached", "-z").split(b"\0")
        if raw
    ]
    return sorted(path for path in paths if path != MANIFEST_NAME)


def main() -> int:
    entries: list[str] = []
    for path in tracked_paths():
        # The index is the source of truth for the commit being prepared.
        # Never include ignored/untracked build caches or local SQLite state.
        data = git_bytes("show", ":" + path)
        entries.append(f"{hashlib.sha256(data).hexdigest()}  {path}")

    OUT.write_text("\n".join(entries) + "\n", encoding="utf-8")
    print(f"Wrote {OUT} with {len(entries)} tracked-file entries")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
