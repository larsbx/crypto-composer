# crypto-composer v0.1
# NOTE: This is intentionally minimal. TODO(v0.2+): add cross-platform packaging, release builds, fuzz targets.

ZIG ?= zig
# On Windows, CI provides the directory containing sqlite3.lib via vcpkg.
SQLITE_LINK_FLAGS ?=

.PHONY: all build test tdd-green fmt fmt-check clean manifest verify-manifest ci

all: test

build:
	$(ZIG) build

test:
	$(ZIG) build test

tdd-green:
	$(ZIG) run tdd_ledger.zig $(SQLITE_LINK_FLAGS) -lc -lsqlite3 -- require-green

fmt:
	$(ZIG) fmt .

fmt-check:
	git ls-files -z -- '*.zig' '*.zon' | xargs -0 $(ZIG) fmt --check

clean:
	rm -rf .zig-cache zig-out

# Hash manifest (SHA-256) of tracked project files.
# TODO(v0.2+): integrate git ls-files when repo is in git.
manifest:
	python3 scripts/make_manifest.py

verify-manifest:
	python3 scripts/verify_manifest.py

ci: fmt-check test verify-manifest tdd-green
