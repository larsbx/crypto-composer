"""Reproducible Git-blob manifest controls. No cryptographic proof is claimed."""
from __future__ import annotations

import hashlib
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
GEN = ROOT / "scripts" / "make_manifest.py"
VERIFY = ROOT / "scripts" / "verify_manifest.py"


def git(repo: Path, *args: str) -> subprocess.CompletedProcess[str]:
    return subprocess.run(["git", "-C", str(repo), *args],
                          check=True, capture_output=True, text=True)


class ManifestRegressionTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.repo = Path(self.temp.name)
        git(self.repo, "init", "-q")
        git(self.repo, "config", "user.name", "Manifest Test")
        git(self.repo, "config", "user.email", "fixture@example.invalid")
        (self.repo / "scripts").mkdir()
        (self.repo / "scripts" / GEN.name).write_bytes(GEN.read_bytes())
        (self.repo / "scripts" / VERIFY.name).write_bytes(VERIFY.read_bytes())
        (self.repo / ".gitignore").write_text(".zig-global/\n*.sqlite\n", encoding="utf-8")
        (self.repo / "source.txt").write_bytes(b"line one\nline two\n")
        git(self.repo, "add", ".")
        git(self.repo, "commit", "-qm", "baseline")
        self.generate_and_commit()

    def execute(self, script: Path):
        return subprocess.run([sys.executable, str(self.repo / "scripts" / script.name)],
                              cwd=self.repo, text=True, capture_output=True)

    def generate_and_commit(self):
        generated = self.execute(GEN)
        self.assertEqual(generated.returncode, 0, generated.stderr)
        git(self.repo, "add", "MANIFEST.SHA256")
        git(self.repo, "commit", "-qm", "record manifest")

    def verify(self):
        return self.execute(VERIFY)

    def test_baseline_verifies(self):
        self.assertEqual(self.verify().returncode, 0)

    def test_ignored_compiler_cache_and_sqlite_excluded(self):
        path = self.repo / ".zig-global" / "z"
        path.mkdir(parents=True)
        (path / "cache.bin").write_bytes(b"local secret cache")
        (self.repo / "private.sqlite").write_bytes(b"private db")
        self.assertEqual(self.verify().returncode, 0)
        manifest = (self.repo / "MANIFEST.SHA256").read_text()
        self.assertNotIn(".zig-global", manifest)
        self.assertNotIn("private.sqlite", manifest)

    def test_windows_crlf_worktree_does_not_change_committed_hashes(self):
        (self.repo / "source.txt").write_bytes(b"line one\r\nline two\r\n")
        # Git blob normalization is exactly the same as with checkout CRLF.
        git(self.repo, "config", "core.autocrlf", "true")
        self.assertEqual(self.verify().returncode, 0)

    def test_missing_line_rejected(self):
        file = self.repo / "MANIFEST.SHA256"
        lines = file.read_text().splitlines()
        file.write_text("\n".join(lines[1:]) + "\n")
        self.assertNotEqual(self.verify().returncode, 0)

    def test_duplicate_line_rejected(self):
        file = self.repo / "MANIFEST.SHA256"
        first = file.read_text().splitlines()[0]
        file.write_text(file.read_text() + first + "\n")
        self.assertNotEqual(self.verify().returncode, 0)

    def test_tampered_hash_rejected(self):
        file = self.repo / "MANIFEST.SHA256"
        data = file.read_text()
        file.write_text(("0" if data[0] != "0" else "1") + data[1:])
        self.assertNotEqual(self.verify().returncode, 0)

    def test_modified_tracked_source_rejected(self):
        (self.repo / "source.txt").write_bytes(b"tampered\n")
        self.assertNotEqual(self.verify().returncode, 0)

    def test_new_tracked_source_without_manifest_rejected(self):
        (self.repo / "new.txt").write_bytes(b"new tracked file")
        git(self.repo, "add", "new.txt")
        git(self.repo, "commit", "-qm", "new source without manifest")
        self.assertNotEqual(self.verify().returncode, 0)

    def test_generator_uses_staged_blob_not_worktree(self):
        (self.repo / "source.txt").write_bytes(b"staged content\n")
        git(self.repo, "add", "source.txt")
        (self.repo / "source.txt").write_bytes(b"working tree changed after staging\n")
        generated = self.execute(GEN)
        self.assertEqual(generated.returncode, 0, generated.stderr)
        lines = (self.repo / "MANIFEST.SHA256").read_text().splitlines()
        target = [s for s in lines if s.endswith("  source.txt")]
        self.assertEqual(target, [
            hashlib.sha256(b"staged content\n").hexdigest() + "  source.txt"
        ])


if __name__ == "__main__":
    unittest.main()
