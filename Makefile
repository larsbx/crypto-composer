# crypto-composer v0.1
# NOTE: This is intentionally minimal. TODO(v0.2+): add cross-platform packaging, release builds, fuzz targets.

ZIG ?= zig

.PHONY: all build test tdd-green fmt fmt-check clean manifest verify-manifest ci

all: test

build:
	$(ZIG) build

test:
	$(ZIG) build test

tdd-green:
	$(ZIG) run tdd_ledger.zig -lsqlite3 -- require-green

fmt:
	$(ZIG) fmt .

fmt-check:
	@# zig fmt has no "check" mode; we enforce formatting by diffing.
	@tmp=$$(mktemp -d);     	rsync -a --exclude .zig-cache --exclude zig-out --exclude .git ./ $$tmp/;     	$(ZIG) fmt $$tmp >/dev/null;     	diff -ruN --exclude .zig-cache --exclude zig-out --exclude .git $$tmp ./;     	rm -rf $$tmp

clean:
	rm -rf .zig-cache zig-out

# Hash manifest (SHA-256) of tracked project files.
# TODO(v0.2+): integrate git ls-files when repo is in git.
manifest:
	python3 scripts/make_manifest.py

verify-manifest:
	python3 scripts/verify_manifest.py

ci: fmt-check test verify-manifest tdd-green
