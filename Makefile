-include .env

.PHONY: all reset clean remove install update build test coverage-report snapshot gas-report anvil deploy

DEFAULT_ANVIL_KEY := 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80

all: install build

reset: clean remove install build

# Clean the repo
clean  :; forge clean

# Remove modules
remove :; rm -rf .gitmodules && rm -rf .git/modules/* && rm -rf lib && touch .gitmodules && git add . && git commit -m "modules"

# Install dependencies
install :; forge install cyfrin/foundry-devops@0.4.0 && forge install foundry-rs/forge-std@v1.13.0 && forge install openzeppelin/openzeppelin-contracts@v5.5.0

# Update Dependencies
update:; forge update

# Build contracts
build:; forge build

# Run test suite
test :; forge test 

# Run forge coverage with minimal fuzz/invariant runs to save time
coverage :; FOUNDRY_PROFILE=coverage forge coverage

# Create test coverage report and save to .txt file
# Use "coverage" foundry profile to prevent crashes due to excessive fuzz and invariant runs
coverage-report :; FOUNDRY_PROFILE=coverage forge coverage --report debug > coverage.txt

# Generate Gas Snapshot
snapshot :; forge snapshot

# Generate table showing gas cost for each function
gas-report :; FOUNDRY_PROFILE=coverage forge test --gas-report > gas.txt

anvil :; anvil -m 'test test test test test test test test test test test junk' --steps-tracing --block-time 1

NETWORK_ARGS := --rpc-url http://localhost:8545 --private-key $(DEFAULT_ANVIL_KEY) --broadcast

ifeq ($(findstring --network eth-MAINNET,$(ARGS)),--network eth MAINNET)
	NETWORK_ARGS := --rpc-url $(ETH_MAINNET_RPC_URL) --account defaultKey --broadcast --verify --etherscan-api-key $(ETHERSCAN_API_KEY) -vvvv
endif

ifeq ($(findstring --network eth-sepolia,$(ARGS)),--network eth sepolia)
	NETWORK_ARGS := --rpc-url $(ETH_SEPOLIA_RPC_URL) --account defaultKey --broadcast --verify --etherscan-api-key $(ETHERSCAN_API_KEY) -vvvv
endif

ifeq ($(findstring --network arb-MAINNET,$(ARGS)),--network arb MAINNET)
	NETWORK_ARGS := --rpc-url $(ARB_MAINNET_RPC_URL) --account defaultKey --broadcast --verify --etherscan-api-key $(ETHERSCAN_API_KEY) -vvvv
endif

ifeq ($(findstring --network arb-sepolia,$(ARGS)),--network arb sepolia)
	NETWORK_ARGS := --rpc-url $(ARB_SEPOLIA_RPC_URL) --account defaultKey --broadcast --verify --etherscan-api-key $(ETHERSCAN_API_KEY) -vvvv
endif

ifeq ($(findstring --network base-MAINNET,$(ARGS)),--network base MAINNET)
	NETWORK_ARGS := --rpc-url $(BASE_MAINNET_RPC_URL) --account defaultKey --broadcast --verify --etherscan-api-key $(ETHERSCAN_API_KEY) -vvvv
endif

ifeq ($(findstring --network base-sepolia,$(ARGS)),--network base sepolia)
	NETWORK_ARGS := --rpc-url $(BASE_SEPOLIA_RPC_URL) --account defaultKey --broadcast --verify --etherscan-api-key $(ETHERSCAN_API_KEY) -vvvv
endif

# deploy contracts with script
deploy:
	@forge script script/DeployDiamond.s.sol:DeployDiamond $(NETWORK_ARGS)
