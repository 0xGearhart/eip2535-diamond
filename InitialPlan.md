Proposed Commit Plan
1) feat/diamond-core-foundation
Add core interfaces:
IDiamondCut.sol
IDiamondLoupe.sol
IERC173.sol
Add core library + proxy:
LibDiamond.sol
Diamond.sol
Add core facets:
DiamondCutFacet.sol
DiamondLoupeFacet.sol
OwnershipFacet.sol
Add basic tests for:
deployment wiring
loupe introspection
ownership
unauthorized diamondCut revert
Commit message: feat: implement EIP-2535 diamond core (cut, loupe, ownership, proxy)
2) feat/diamond-upgrade-lifecycle-tests
Add targeted upgrade lifecycle tests (no ERC-20 yet):
add selector
replace selector
remove selector
invalid cut edge cases
Add small mock facets for replacement/remove scenarios in test/mocks/
Commit message: test: cover diamond add/replace/remove lifecycle and cut edge cases
3) feat/erc20-storage-and-facet
Add ERC-20 app storage library:
LibAppStorage.sol (or LibERC20Storage.sol)
Add ERC-20 facet:
ERC20Facet.sol
Include:
name/symbol/decimals/totalSupply/balanceOf/transfer/approve/allowance/transferFrom
owner mint
holder burn
(optional) burnFrom
Commit message: feat: add ERC20 facet with mint/burn and diamond storage
4) feat/diamond-init-erc20-bootstrap
Add initializer contract:
DiamondInit.sol
Implement one-time init guard and metadata/supply initialization
Add tests for:
init success path
re-init prevention
init delegatecall failure propagation
Commit message: feat: add DiamondInit for ERC20 metadata/supply bootstrap
5) chore/deployment-script-refactor
Implement full deployment flow:
deploy cut facet
deploy diamond
deploy loupe/ownership/erc20/init
execute initial diamondCut + init calldata
log addresses
Update Makefile target if needed
Commit message: chore: implement full diamond deployment script and fix naming
1) test/erc20-integration-and-fuzz
Add deterministic ERC-20 integration tests through diamond proxy
Add fuzz tests:
transfer conservation
allowance/spend behavior
Commit message: test: add ERC20 integration and fuzz coverage through diamond proxy
1) test/invariants-diamond-erc20
Add invariants:
sum balances = total supply
selector mapping consistency
loupe internal consistency
Commit message: test: add invariant suite for diamond selector table and ERC20 accounting
1) docs/readme-diamond-architecture
Update README.md with architecture, facet list, deployment and testing commands
Commit message: docs: document diamond architecture, deployment, and test strategy

- Suggested Order of Review
Core architecture (commits 1-2)
Token functionality (commits 3-4)
Operational tooling (commit 5)
Quality hardening (commits 6-7)
Documentation (commit 8)

- Definition of Done Per Commit
forge build passes
relevant forge test --match-path ... passes
no unrelated file churn
commit message reflects only that slice