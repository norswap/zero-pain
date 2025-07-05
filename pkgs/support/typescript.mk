build: ## Builds TypeScript outputs
	turbo build --filter=$(pkg)...
.PHONY: build

typecheck: ## Types-check the code
	turbo typecheck --filter=$(pkg)...
.PHONY: typecheck

clean: ## Remove TypeScript outputs
	rm -rf build
.PHONY: clean

nuke: clean ## Clean + removes all derived files
	rm -rf .turbo
.PHONY: nuke