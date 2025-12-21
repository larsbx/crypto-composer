#!/usr/bin/env bash
set -euo pipefail

ZIG="${ZIG:-zig}"

echo "[1/3] zig version"
$ZIG version

echo "[2/3] format check (diff-based)"
make fmt-check

echo "[3/3] tests"
$ZIG build test
