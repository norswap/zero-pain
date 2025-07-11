include ../support/lib.mk
include ../support/help.mk

# include .env file and export its env vars
# (-include to ignore error if it does not exist)
-include .env

# Set CONFIG to "LOCAL" by default. Other valid values: "TEST" or "MAIN".
# Must be exported as some deploy scripts depend on it.
export CONFIG ?= LOCAL

# Type of proxy contract to use for happy accounts in DeployBoop.s.sol.
# Valid values: "BEACON" or "UUPS". Defaults to BEACON.
export PROXY_TYPE ?= BEACON

# Port at which Anvil will be running.
export ANVIL_PORT ?= 8545

# Block time for Anvil, automining if 0
export ANVIL_BLOCK_TIME ?= 2

ANVIL_BLOCK_TIME_ARG := $(if $(findstring '0','$(ANVIL_BLOCK_TIME)'),,--block-time $(ANVIL_BLOCK_TIME))

# Deployment mode:
# - "deploy" — deploy contracts normally
# - "dry" — for a dry-run that doesn't send transactions
# - "resume" — resumes the previous deployment
DEPLOY ?= deploy

# Flags for `ln` (symlink creation)
LN_FLAGS := $(if $(findstring Darwin,$(shell uname)),-shF,-sfT)

# Flag to include or exclude metadata based on configuration
METADATA_FLAG := $(if $(findstring false,$(APPEND_METADATA_$(CONFIG))),--no-metadata,)

# See README.md for more documentation.

# Location of top-level node_modules relative to the current package.
# We need the top-level on with Bun, because it leaves the package-specific ones empty.
NODE_MODULES := ../../node_modules

# The reason for this weird setup is that the IntelliJ solidity plugin will not resolve imports
# if they're not in `lib` and do not have a `src` directory (the `remappings.txt` file is ignored).
setup:
	if [ ! -f .env ]; then cp .env.example .env; fi
	rm -rf lib
	mkdir -p lib
	ln $(LN_FLAGS) ../$(NODE_MODULES)/forge-std lib/forge-std
	ln $(LN_FLAGS) ../$(NODE_MODULES)/@layerzerolabs lib/layerzero
	ln $(LN_FLAGS) ../$(NODE_MODULES)/@openzeppelin lib/openzeppelin
	ln $(LN_FLAGS) ../$(NODE_MODULES)/solidity-bytes-utils lib/solidity-bytes-utils
	ln $(LN_FLAGS) ../$(NODE_MODULES)/solady lib/solady
	ln $(LN_FLAGS) ../$(NODE_MODULES)/ExcessivelySafeCall lib/ExcessivelySafeCall
.PHONY: setup

####################################################################################################
# Build

build: ## Builds all contracts
	forge build $(METADATA_FLAG)
.PHONY: build

watch: ## Builds contracts & runs tests on contract change
	forge test --watch src/
.PHONY: watch

clean: ## Removes build output
	@# Avoid failures when trying to clean after a preceding `make nuke`.
	forge clean > /dev/null 2> /dev/null || true
	rm -rf node_modules/.tmp
	rm -rf docs
.PHONY: clean

nuke: clean ## Removes build output and dependencies
	rm -rf lib
.PHONY: nuke

####################################################################################################
##@ Testing

test: ## Runs tests
	forge test -vvv
.PHONY: test

testv: ## Runs test with max verbosity
	forge test -vvvv
.PHONY: testv

test-fork: ## Runs test on a fork of the network (via RPC_$(CONFIG) env variable)
	forge test --gas-report --fork-url $(RPC_$(CONFIG))
.PHONY: test-fork

test-gas: ## Runs test and generate a gas report
	forge test --gas-report
.PHONY: test-gas

####################################################################################################
##@ Code Quality

forge-fmt-check:
	@forge fmt --check src || true
.PHONY: forge-fmt-check

forge-fmt:
	@forge fmt src || true
.PHONY: forge-fmt

# NOTE(Solhint):
# Should re-enable gas-calldata-parameters & gas-increment-by-one.

solhint-check:
	solhint --config ./.solhint.json "src/**/*.sol";
.PHONY: solhint-check

solhint:
	solhint --config ./.solhint.json "src/**/*.sol" --fix --noPrompt;
.PHONY: solhint

check: forge-fmt-check solhint-check ## Checks formatting & linting (no files touched)
.PHONY: check

format: forge-fmt solhint ## Formats & lint (autofixes)
.PHONY: format

####################################################################################################
##@ Devnet

anvil: ## Runs anvil at $ANVIL_PORT (blocking)
	anvil --port $(ANVIL_PORT) $(ANVIL_BLOCK_TIME_ARG) --print-traces
.PHONY: anvil

anvil-background: ## Runs anvil at in the background at $ANVIL_PORT, logging to anvil.log
	anvil --port $(ANVIL_PORT) $(ANVIL_BLOCK_TIME_ARG) > anvil.log 2>&1 &
	@echo "Running Anvil at {http,ws}://localhost:$(ANVIL_PORT)"
.PHONY: anvil-background

kill-anvil: ## Kill an existing Anvil process running at $ANVIL_PORT
	@lsof -t -iTCP:$(ANVIL_PORT) -sTCP:LISTEN | xargs kill -9 2>/dev/null || true
.PHONY: kill-anvil

####################################################################################################
##@ Deployment

strip_quotes = $(shell echo $(1) | sed -e 's/^["'\'']//; s/["'\'']$$//')
VERIFY_FLAG := $(if $(findstring true,$(VERIFY_$(CONFIG))),--verify,)
VERIFIER_FLAG := $(if $(findstring true,$(VERIFY_$(CONFIG))),$(call strip_quotes,$(VERIFIER_FLAG_$(CONFIG))),)
VERIFIER_URL := $(if $(findstring true,$(VERIFY_$(CONFIG))),$(call strip_quotes,$(VERIFIER_URL_$(CONFIG))),)
CHECK_UPGRADE := true

ifeq ($(DEPLOY),deploy)
	BROADCAST_FLAG := --broadcast
endif

ifeq ($(DEPLOY),dry)
	BROADCAST_FLAG :=
	VERIFY_FLAG :=
endif

ifeq ($(DEPLOY),resume)
	BROADCAST_FLAG := --resume
	CHECK_UPGRADE := false
endif

# Deploys contracts locally, to testnet or mainnet depending on the $CONFIG value.
# The deploy script to use is picked from `src/deploy/$DEPLOY_SCRIPT`.
# You can also specify MODE=dry to not submit the tx, or MODE=resume to resume the last deployment.
deploy:
	$(call run-script,src/deploy/$(DEPLOY_SCRIPT))
	$(call post-deploy)
	$(call save-deployment)
.PHONY: deploy

# Runs the script given in $SCRIPT, either locally, to testnet or mainnet depending on the $CONFIG value.
# The script to use is picked from `src/scripts/$SCRIPT`.
# You can also specify MODE=dry to not submit the txs.
run:
	$(call run-script,src/scripts/$(SCRIPT))
.PHONY: run

# Defines run-script to use environment variable keys or Foundry accounts depending on the
# value of USE_FOUNDRY_ACCOUNT.
define run-script
	$(eval __USE_ACC := $(findstring true,$(USE_FOUNDRY_ACCOUNT)))
	$(eval __DEPLOY_FUNC := $(if $(__USE_ACC),run-script-account,run-script-key))
	$(call $(__DEPLOY_FUNC),$(1))
endef

# Deploys using a private key supplied in an environment variable (dependent on the $CONFIG value).
define run-script-key
    @# Command intentionally output.
	forge script $(1) \
		--fork-url $(RPC_$(CONFIG)) \
		--private-key $(PRIVATE_KEY_$(CONFIG)) \
		$(BROADCAST_FLAG) \
		$(VERIFY_FLAG) \
		$(VERIFIER_FLAG) \
		$(VERIFIER_URL) \
		$(METADATA_FLAG) -vvvv
endef

# Deploys using a private key supplied by a Foundry account. The account name and password file
# are supplied in environment variables (dependent on the $CONFIG value).
define run-script-account
	@$(eval DEPLOY_SENDER := `cast wallet address \
		--account $(ACCOUNT_$(CONFIG)) \
		--password-file $(PASSFILE_$(CONFIG))`)
	@# Command intentionally output.
	forge script $(1) \
		--fork-url $(RPC_$(CONFIG)) \
		--account $(ACCOUNT_$(CONFIG)) \
		--password-file $(PASSFILE_$(CONFIG)) \
		--sender $(DEPLOY_SENDER) \
		$(BROADCAST_FLAG) \
		$(VERIFY_FLAG) \
		$(VERIFIER_FLAG) \
		$(VERIFIER_URL) \
		$(METADATA_FLAG) -vvvv
endef

# Post-processes the deployment output.
define post-deploy
	@# Print address logs from the deploy script.
	@cat out/deployment.json && printf "\n"

	@# Extract ABIs from the deployed contracts and save to out/abis.json.
	@# The metadata flag is crucial to avoid invalidating the build.
	@export CONTRACTS=$$(bun node-jq '[.[]] | unique' out/abiMap.json) && \
	node-jq '[.[]] | unique[]' out/abiMap.json \
		| xargs -I'{}' forge inspect {} abi --json $(METADATA_FLAG) \
		| node-jq --slurp --argjson contracts "$$CONTRACTS" '[$$contracts, .] | transpose | map({ (.[0]): .[1] }) | add' \
		> out/abis.json;

	@# Generate "as const" TypeScript ABI definitions for type usage.
	@# To use you will want to symlink this file from the deployments dir to the consuming package,
	@# and .gitignore it.

	@cat scripts/abi_types_fragment_begin.ts.txt > out/abis.ts
	@printf "\n\n" >> out/abis.ts

	@printf "const contractToAbi = (" >> out/abis.ts
	@cat out/abis.json >> out/abis.ts
	@printf ") as const\n\n" >> out/abis.ts

	@printf "const aliasToContract = (" >> out/abis.ts
	@cat out/abiMap.json >> out/abis.ts
	@printf ") as const\n\n" >> out/abis.ts

	@printf "export const deployment = (" >> out/abis.ts
	@cat out/deployment.json >> out/abis.ts
	@printf ") as const\n\n" >> out/abis.ts

	@cat scripts/abi_types_fragment_end.ts.txt >> out/abis.ts
	@printf "\n" >> out/abis.ts
endef

# Explanation of the jq command;
#    CONTRACTS == [ "Contract1", "Contract2", ... ]
#    The command up to xargs sequentially emit the ABI (JSON objects) of each contract.
#	 The jq command in the '--slurp' line starts by creating [CONTRACTS, ArrayOfABIs]
#    It then transposes it: [ ["Contract1", ABI1], ["Contract2", ABI2], ... ]
#    Finally, it maps it to [{ "Contract1": ABI1 } , { "Contract2": ABI2 } , ... ]
#    then joins alls of them in a single JSON dictionary.

# Saves all information pertaining to a deployment to deployments/$DEPLOYMENT_NAME.
# The suggested $DEPLOYMENT_NAME format is "CHAIN/NAME", e.g. "happy-sepolia/aa".
# Will save the latest deployment from $DEPLOY_SCRIPT.
define save-deployment
	@mkdir -p deployments/$(DEPLOYMENT_NAME)
	@cp -f out/{deployment.json,abiMap.json,abis.json,abis.ts} deployments/$(DEPLOYMENT_NAME)
	$(eval __CHAIN_ID := `cast chain-id --rpc-url $(RPC_$(CONFIG))`)
	$(eval __RUN_FILE := broadcast/$(DEPLOY_SCRIPT)/$(__CHAIN_ID)/run-latest.json)
	@echo "Saved deployment to deployments/$(DEPLOYMENT_NAME)"
endef

####################################################################################################
# Deploy Scripts

# Defines and exports an env variable
define set-var
	export $(1)=$(2)
endef

# Sets CHAIN_ID based on RPC.
define set-chain-id
	export CHAIN_ID = $(shell cast chain-id --rpc-url $(RPC_$(CONFIG)))
endef

# Sets CHAIN_NAME based on CHAIN_ID when called.
define set-chain-name
	ifeq ($(CHAIN_ID),31337)
		export CHAIN_NAME = anvil
	else ifeq ($(CHAIN_ID),216)
		export CHAIN_NAME = happy-sepolia
	else ifeq ($(CHAIN_ID),11155111)
		export CHAIN_NAME = sepolia
	else ifeq ($(CHAIN_ID),1)
		export CHAIN_NAME = ethereum
	else ifeq ($(CHAIN_ID),421614)
		export CHAIN_NAME = arb-sepolia
	else ifeq ($(CHAIN_ID),11155420)
		export CHAIN_NAME = op-sepolia
	else
		export CHAIN_NAME = unknown
	endif
endef

# Sets CHAIN_ID and CHAIN_NAME, defines and *exports* DEPLOYMENT_NAME = CHAIN_NAME/$(1)
# Call like this: $(eval $(call set-deployment-name,myDeployment))
define set-deployment-name
	$(eval $(set-chain-id))
	$(eval $(set-chain-name))
	# Export for use in recursive make invocations.
	export DEPLOYMENT_NAME := $(CHAIN_NAME)/$(1)
endef

deploy-messaging:
	$(eval $(call set-deployment-name,messaging))
	make deploy DEPLOY_SCRIPT=DeployOApp.s.sol
.PHONY: deploy-messaging

deploy-messaging-op: ## Deploys the LayerZero contracts on OP Sepolia
	$(eval $(call set-var,CHAIN_NYM,OP))
	$(eval $(call set-var,CONFIG,TEST))
	make deploy-messaging
.PHONY: deploy-messaging-op

deploy-messaging-arb: ## Deploys the LayerZero contracts on Arbitrum Sepolia
	$(eval $(call set-var,CHAIN_NYM,ARB))
	$(eval $(call set-var,CONFIG,TEST))
	$(eval $(call set-deployment-name,messaging))
	make deploy DEPLOY_SCRIPT=DeployOApp.s.sol
.PHONY: deploy-messaging-arb

deploy-boop:
	$(eval $(call set-deployment-name,boop))
	make deploy DEPLOY_SCRIPT=DeployBoop.s.sol
.PHONY: deploy-boop

deploy-boop-op: ## Deploys the Boop contracts on OP Sepolia
	$(eval $(call set-var,CHAIN_NYM,OP))
	$(eval $(call set-var,CONFIG,TEST))
	make deploy-boop
.PHONY: deploy-boop-op

deploy-mocks-op: ## Deploys the mock contracts on OP Sepolia
	$(eval $(call set-var,CHAIN_NYM,OP))
	$(eval $(call set-var,CONFIG,TEST))
	$(eval $(call set-deployment-name,mocks))
	make deploy DEPLOY_SCRIPT=DeployMocks.s.sol
.PHONY: deploy-mocks-op

deploy-boop-arb: ## Deploys the Boop contracts on Arbitrum Sepolia
	$(eval $(call set-var,CHAIN_NYM,ARB))
	$(eval $(call set-var,CONFIG,TEST))
	$(eval $(call set-deployment-name,boop))
	make deploy DEPLOY_SCRIPT=DeployBoop.s.sol
.PHONY: deploy-boop-op

deploy-mocks:
	$(eval $(call set-deployment-name,mocks))
	make deploy DEPLOY_SCRIPT=DeployMocks.s.sol
.PHONY: deploy-mocks

deploy-mocks-arb: ## Deploys the mock contracts on Arbitrum Sepolia
	$(eval $(call set-var,CHAIN_NYM,ARB))
	$(eval $(call set-var,CONFIG,TEST))
	make deploy-mocks
.PHONY: deploy-mocks-op

deploy-local:
	$(eval $(call set-var,CONFIG,LOCAL))
	make deploy-boop
	make deploy-mocks
.PHONY: deploy-local

####################################################################################################
# Scripts

deploy-account:
	$(eval $(call set-var,CHAIN_NYM,OP))
	$(eval $(call set-var,CONFIG,TEST))
	$(eval $(call set-var,DEPLOY,dry))
	$(eval $(set-chain-id))
	$(eval $(call set-chain-name))

	make run SCRIPT=DeployAccount.s.sol
.PHONY: deploy-account

send-boop:
	$(eval $(call set-var,CHAIN_NYM,OP))
	$(eval $(call set-var,CONFIG,TEST))
	make run SCRIPT=SendBoop.s.sol
.PHONY: send-boop

####################################################################################################