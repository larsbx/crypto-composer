#!/usr/bin/env python3
"""Standalone TDD ledger backed by SQLite.

Drop this file into any repo and run `python3 tdd_ledger.py --help`.
The ledger enforces a red->green workflow by recording failing tests first.
"""

from __future__ import annotations

import argparse
import os
import sqlite3
import subprocess
import sys
from typing import Iterable, Optional


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="TDD ledger backed by SQLite.")
    parser.add_argument(
        "--db",
        default=os.environ.get("TDD_LEDGER_DB", ".tdd_ledger.sqlite"),
        help="Path to sqlite db (default: .tdd_ledger.sqlite or TDD_LEDGER_DB).",
    )
    sub = parser.add_subparsers(dest="command", required=True)

    sub.add_parser("init", help="Initialize the ledger database.")

    red = sub.add_parser("red", help="Record a failing test.")
    red.add_argument("test", help="Test name or identifier.")
    red.add_argument("--note", default=None, help="Optional note.")
    red.add_argument("--run", nargs=argparse.REMAINDER, help="Command to run (expects failure).")

    green = sub.add_parser("green", help="Record a passing test.")
    green.add_argument("test", help="Test name or identifier.")
    green.add_argument("--note", default=None, help="Optional note.")
    green.add_argument("--run", nargs=argparse.REMAINDER, help="Command to run (expects success).")

    sub.add_parser("require-green", help="Exit non-zero if any tests are still red.")
    sub.add_parser("status", help="Print status summary.")

    return parser.parse_args()


def connect(db_path: str) -> sqlite3.Connection:
    conn = sqlite3.connect(db_path)
    conn.execute("PRAGMA journal_mode = WAL;")
    conn.execute("PRAGMA foreign_keys = ON;")
    return conn


def init_db(conn: sqlite3.Connection) -> None:
    conn.execute(
        """
        CREATE TABLE IF NOT EXISTS ledger (
            test_name TEXT PRIMARY KEY,
            status TEXT NOT NULL CHECK(status IN ('red','green')),
            note TEXT,
            last_command TEXT,
            last_exit_code INTEGER,
            created_at TEXT NOT NULL DEFAULT (datetime('now')),
            updated_at TEXT NOT NULL DEFAULT (datetime('now'))
        );
        """
    )
    conn.execute(
        """
        CREATE TABLE IF NOT EXISTS events (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            test_name TEXT NOT NULL,
            status TEXT NOT NULL CHECK(status IN ('red','green')),
            note TEXT,
            command TEXT,
            exit_code INTEGER,
            created_at TEXT NOT NULL DEFAULT (datetime('now'))
        );
        """
    )
    conn.commit()


def normalize_run_args(run_args: Optional[Iterable[str]]) -> Optional[list[str]]:
    if not run_args:
        return None
    args = list(run_args)
    if args and args[0] == "--":
        args = args[1:]
    if not args:
        return None
    return args


def run_command(args: list[str]) -> int:
    proc = subprocess.run(args, check=False)
    return proc.returncode


def upsert_ledger(
    conn: sqlite3.Connection,
    test: str,
    status: str,
    note: Optional[str],
    command: Optional[str],
    exit_code: Optional[int],
) -> None:
    conn.execute(
        """
        INSERT INTO ledger (test_name, status, note, last_command, last_exit_code)
        VALUES (?, ?, ?, ?, ?)
        ON CONFLICT(test_name) DO UPDATE SET
            status=excluded.status,
            note=excluded.note,
            last_command=excluded.last_command,
            last_exit_code=excluded.last_exit_code,
            updated_at=datetime('now');
        """,
        (test, status, note, command, exit_code),
    )
    conn.execute(
        """
        INSERT INTO events (test_name, status, note, command, exit_code)
        VALUES (?, ?, ?, ?, ?);
        """,
        (test, status, note, command, exit_code),
    )
    conn.commit()


def cmd_red(conn: sqlite3.Connection, args: argparse.Namespace) -> int:
    run_args = normalize_run_args(args.run)
    exit_code: Optional[int] = None
    cmd_str: Optional[str] = None
    if run_args:
        cmd_str = " ".join(run_args)
        exit_code = run_command(run_args)
        if exit_code == 0:
            print("expected failing test, but command exited 0", file=sys.stderr)
            return 2
    upsert_ledger(conn, args.test, "red", args.note, cmd_str, exit_code)
    return 0


def cmd_green(conn: sqlite3.Connection, args: argparse.Namespace) -> int:
    run_args = normalize_run_args(args.run)
    exit_code: Optional[int] = None
    cmd_str: Optional[str] = None
    if run_args:
        cmd_str = " ".join(run_args)
        exit_code = run_command(run_args)
        if exit_code != 0:
            print("expected passing test, but command failed", file=sys.stderr)
            return 2
    upsert_ledger(conn, args.test, "green", args.note, cmd_str, exit_code)
    return 0


def cmd_require_green(conn: sqlite3.Connection) -> int:
    rows = conn.execute(
        "SELECT test_name FROM ledger WHERE status = 'red' ORDER BY test_name;"
    ).fetchall()
    if rows:
        print("red tests remain:", file=sys.stderr)
        for (name,) in rows:
            print(f"- {name}", file=sys.stderr)
        return 1
    return 0


def cmd_status(conn: sqlite3.Connection) -> int:
    rows = conn.execute(
        "SELECT status, COUNT(*) FROM ledger GROUP BY status ORDER BY status;"
    ).fetchall()
    counts = {status: count for status, count in rows}
    red = counts.get("red", 0)
    green = counts.get("green", 0)
    print(f"red={red} green={green}")
    return 0


def main() -> int:
    args = parse_args()
    conn = connect(args.db)
    init_db(conn)

    if args.command == "init":
        return 0
    if args.command == "red":
        return cmd_red(conn, args)
    if args.command == "green":
        return cmd_green(conn, args)
    if args.command == "require-green":
        return cmd_require_green(conn)
    if args.command == "status":
        return cmd_status(conn)

    print("unknown command", file=sys.stderr)
    return 2


if __name__ == "__main__":
    raise SystemExit(main())
