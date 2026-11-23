BUMP ?= patch
export BUMP

.PHONY: help test release-dry-run release
help:
	@echo 'make test | make release-dry-run [BUMP=patch|minor|major] | make release [BUMP=patch|minor|major]'

test:
	swift test

release-dry-run:
	@python3 scripts/release.py --dry-run

release:
	@python3 scripts/release.py
