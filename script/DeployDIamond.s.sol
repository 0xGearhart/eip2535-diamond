// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {CodeConstants, HelperConfig} from "./HelperConfig.s.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {Script, console2} from "forge-std/Script.sol";
import {Diamond} from "src/Diamond.sol";
import {DiamondCutFacet} from "src/facets/DiamondCutFacet.sol";
import {DiamondLoupeFacet} from "src/facets/DiamondLoupeFacet.sol";
import {ERC20Facet} from "src/facets/ERC20Facet.sol";
import {OwnershipFacet} from "src/facets/OwnershipFacet.sol";
import {IDiamondCut} from "src/interfaces/IDiamondCut.sol";
import {IDiamondLoupe} from "src/interfaces/IDiamondLoupe.sol";
import {IERC173} from "src/interfaces/IERC173.sol";
import {DiamondInit} from "src/upgradeInitializers/DiamondInit.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

contract DeployDiamond is Script, CodeConstants {
    // Bundles addresses produced by the deployment flow for script logs and tests.
    struct DeployedCore {
        address diamond;
        address cutFacet;
        address loupeFacet;
        address ownershipFacet;
        address erc20Facet;
        address diamondInit;
    }

    function run() external returns (DeployedCore memory deployed) {
        // Resolve chain-aware deployer account and shared constants from helper config.
        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory config = helperConfig.getNetworkConfig();

        console2.log("Deploying diamond");
        console2.log("Chain ID:", block.chainid);
        console2.log("Owner/Deployer:", config.account);
        console2.log("ERC20 init name:", TOKEN_NAME);
        console2.log("ERC20 init symbol:", TOKEN_SYMBOL);
        console2.log("ERC20 init decimals:", TOKEN_DECIMALS);
        console2.log("ERC20 init supply:", INITIAL_SUPPLY);

        vm.startBroadcast(config.account);
        // Execute the full deployment + initial cut in one deterministic path.
        deployed = deployCore(config.account);
        vm.stopBroadcast();

        _logDeployment(deployed);
    }

    function deployCore(address owner) internal returns (DeployedCore memory deployed) {
        // Deploy the immutable bootstrap facet and diamond proxy.
        DiamondCutFacet cutFacet = new DiamondCutFacet();
        Diamond diamond = new Diamond(owner, address(cutFacet));

        // Deploy runtime facets and initializer contract.
        DiamondLoupeFacet loupeFacet = new DiamondLoupeFacet();
        OwnershipFacet ownershipFacet = new OwnershipFacet();
        ERC20Facet erc20Facet = new ERC20Facet();
        DiamondInit diamondInit = new DiamondInit();

        // Build the initial selector cut (loupe + ownership + ERC20).
        IDiamondCut.FacetCut[] memory cut = new IDiamondCut.FacetCut[](3);
        cut[0] = IDiamondCut.FacetCut({
            facetAddress: address(loupeFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: _loupeSelectors()
        });
        cut[1] = IDiamondCut.FacetCut({
            facetAddress: address(ownershipFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: _ownershipSelectors()
        });
        cut[2] = IDiamondCut.FacetCut({
            facetAddress: address(erc20Facet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: _erc20Selectors()
        });

        // Apply cut and run initializer to set ERC20 metadata + initial supply.
        IDiamondCut(address(diamond)).diamondCut(cut, address(diamondInit), _erc20InitCalldata(owner));

        deployed = DeployedCore({
            diamond: address(diamond),
            cutFacet: address(cutFacet),
            loupeFacet: address(loupeFacet),
            ownershipFacet: address(ownershipFacet),
            erc20Facet: address(erc20Facet),
            diamondInit: address(diamondInit)
        });
    }

    function _loupeSelectors() internal pure returns (bytes4[] memory selectors) {
        // ERC-2535 loupe + ERC-165 introspection selectors.
        selectors = new bytes4[](5);
        selectors[0] = IDiamondLoupe.facets.selector;
        selectors[1] = IDiamondLoupe.facetFunctionSelectors.selector;
        selectors[2] = IDiamondLoupe.facetAddresses.selector;
        selectors[3] = IDiamondLoupe.facetAddress.selector;
        selectors[4] = IERC165.supportsInterface.selector;
    }

    function _ownershipSelectors() internal pure returns (bytes4[] memory selectors) {
        // IERC173 ownership selectors plus explicit renounce.
        selectors = new bytes4[](3);
        selectors[0] = IERC173.owner.selector;
        selectors[1] = IERC173.transferOwnership.selector;
        selectors[2] = OwnershipFacet.renounceOwnership.selector;
    }

    function _erc20Selectors() internal pure returns (bytes4[] memory selectors) {
        // ERC20 core + metadata + project-specific mint/burn extensions.
        selectors = new bytes4[](12);
        selectors[0] = IERC20Metadata.name.selector;
        selectors[1] = IERC20Metadata.symbol.selector;
        selectors[2] = IERC20Metadata.decimals.selector;
        selectors[3] = IERC20.totalSupply.selector;
        selectors[4] = IERC20.balanceOf.selector;
        selectors[5] = IERC20.transfer.selector;
        selectors[6] = IERC20.allowance.selector;
        selectors[7] = IERC20.approve.selector;
        selectors[8] = IERC20.transferFrom.selector;
        selectors[9] = ERC20Facet.mint.selector;
        selectors[10] = ERC20Facet.burn.selector;
        selectors[11] = ERC20Facet.burnFrom.selector;
    }

    function _erc20InitCalldata(address owner) internal pure returns (bytes memory) {
        // Encode initializer args once so script and tests share the same init semantics.
        return abi.encodeWithSelector(DiamondInit.init.selector, TOKEN_NAME, TOKEN_SYMBOL, TOKEN_DECIMALS, owner, INITIAL_SUPPLY);
    }

    function _logDeployment(DeployedCore memory deployed) internal view {
        console2.log("Diamond deployed:");
        console2.log("  chainId", block.chainid);
        console2.log("  diamond", deployed.diamond);
        console2.log("  cutFacet", deployed.cutFacet);
        console2.log("  loupeFacet", deployed.loupeFacet);
        console2.log("  ownershipFacet", deployed.ownershipFacet);
        console2.log("  erc20Facet", deployed.erc20Facet);
        console2.log("  diamondInit", deployed.diamondInit);
    }
}
