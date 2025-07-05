define with_pkg_or
	$(if $(pkg) , cd pkgs/$(pkg) && $(1) , $(2))
endef

run: ## Runs a command in package, e.g. `make run pkg=utils cmd=typecheck` runs `cd packages/utils && make typecheck`
	$(call with_pkg_or , make $(cmd) , make $(cmd))
.PHONY: run

setup: ## Installs from lockfile
	bun install --frozen-lockfile
.PHONY: setup

install: ## Installs, updating lockfile if needed
	bun install
.PHONY: install

build: ## Builds TypeScript outputs, targeting a package if `pkg=<package>` is specified
	$(call with_pkg_or , make build , turbo build)
.PHONY: build

typecheck: ## Builds TypeScript outputs, targeting a package if `pkg=<package>` is specified
	$(call with_pkg_or , make typecheck , turbo typecheck)
.PHONY: typecheck

clean: ## Remove TypeScript outputs, targeting a package if `pkg=<package>` is specified
	$(call with_pkg_or , turbo make --cache=local: -- clean , make clean)
.PHONY: clean

nuke: ## clean + removes all derived files (e.g. node_modules, Turborepo caches)
	turbo make --cache=local: -- nuke
	rm -rf node_modules
	rm -rf .turbo
.PHONY: nuke

reset: nuke install ## nuke + install
.PHONY: reset