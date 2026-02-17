// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {CodeConstants, HelperConfig} from "./HelperConfig.s.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {Script} from "forge-std/Script.sol";
import {Diamond} from "src/Diamond.sol";
import {DiamondCutFacet} from "src/facets/DiamondCutFacet.sol";
import {DiamondLoupeFacet} from "src/facets/DiamondLoupeFacet.sol";
import {OwnershipFacet} from "src/facets/OwnershipFacet.sol";
import {IDiamondCut} from "src/interfaces/IDiamondCut.sol";
import {IDiamondLoupe} from "src/interfaces/IDiamondLoupe.sol";
import {IERC173} from "src/interfaces/IERC173.sol";

contract DeployDiamond is Script, CodeConstants {
    struct DeployedCore {
        address diamond;
        address cutFacet;
        address loupeFacet;
        address ownershipFacet;
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

        IDiamondCut.FacetCut[] memory cut = new IDiamondCut.FacetCut[](2);
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

        IDiamondCut(address(diamond)).diamondCut(cut, address(0), "");

        deployed = DeployedCore({
            diamond: address(diamond),
            cutFacet: address(cutFacet),
            loupeFacet: address(loupeFacet),
            ownershipFacet: address(ownershipFacet)
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
}
