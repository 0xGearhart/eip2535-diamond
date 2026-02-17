// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {CodeConstants, HelperConfig} from "./HelperConfig.s.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {Script} from "forge-std/Script.sol";
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
    struct DeployedCore {
        address diamond;
        address cutFacet;
        address loupeFacet;
        address ownershipFacet;
        address erc20Facet;
        address init;
    }

    function run() external returns (DeployedCore memory deployed) {
        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory config = helperConfig.getNetworkConfig();

        vm.startBroadcast(config.account);
        deployed = deployCore(config.account);
        vm.stopBroadcast();
    }

    function deployCore(address owner) internal returns (DeployedCore memory deployed) {
        DiamondCutFacet cutFacet = new DiamondCutFacet();
        Diamond diamond = new Diamond(owner, address(cutFacet));

        DiamondLoupeFacet loupeFacet = new DiamondLoupeFacet();
        OwnershipFacet ownershipFacet = new OwnershipFacet();
        ERC20Facet erc20Facet = new ERC20Facet();
        DiamondInit diamondInit = new DiamondInit();

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

        IDiamondCut(address(diamond)).diamondCut(cut, address(diamondInit), _erc20InitCalldata(owner));

        deployed = DeployedCore({
            diamond: address(diamond),
            cutFacet: address(cutFacet),
            loupeFacet: address(loupeFacet),
            ownershipFacet: address(ownershipFacet),
            erc20Facet: address(erc20Facet),
            init: address(diamondInit)
        });
    }

    function _loupeSelectors() internal pure returns (bytes4[] memory selectors) {
        selectors = new bytes4[](5);
        selectors[0] = IDiamondLoupe.facets.selector;
        selectors[1] = IDiamondLoupe.facetFunctionSelectors.selector;
        selectors[2] = IDiamondLoupe.facetAddresses.selector;
        selectors[3] = IDiamondLoupe.facetAddress.selector;
        selectors[4] = IERC165.supportsInterface.selector;
    }

    function _ownershipSelectors() internal pure returns (bytes4[] memory selectors) {
        selectors = new bytes4[](3);
        selectors[0] = IERC173.owner.selector;
        selectors[1] = IERC173.transferOwnership.selector;
        selectors[2] = OwnershipFacet.renounceOwnership.selector;
    }

    function _erc20Selectors() internal pure returns (bytes4[] memory selectors) {
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
        return abi.encodeWithSelector(DiamondInit.init.selector, TOKEN_NAME, TOKEN_SYMBOL, TOKEN_DECIMALS, owner, INITIAL_SUPPLY);
    }
}
