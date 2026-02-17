// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {Test} from "forge-std/Test.sol";
import {DeployDiamond} from "script/DeployDiamond.s.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {Diamond} from "src/Diamond.sol";
import {DiamondCutFacet} from "src/facets/DiamondCutFacet.sol";
import {DiamondLoupeFacet} from "src/facets/DiamondLoupeFacet.sol";
import {OwnershipFacet} from "src/facets/OwnershipFacet.sol";
import {IDiamondCut} from "src/interfaces/IDiamondCut.sol";
import {IDiamondLoupe} from "src/interfaces/IDiamondLoupe.sol";
import {IERC173} from "src/interfaces/IERC173.sol";
import {LibDiamond} from "src/libraries/LibDiamond.sol";

contract DeployDiamondTest is Test {
    Diamond internal diamond;
    DiamondCutFacet internal cutFacet;
    DiamondLoupeFacet internal loupeFacet;
    OwnershipFacet internal ownershipFacet;

    IDiamondCut internal diamondCut;
    IDiamondLoupe internal loupe;
    IERC173 internal ownership;

    address internal user = makeAddr("user");
    address internal owner;
    HelperConfig.NetworkConfig config;

    function setUp() public {
        HelperConfig helperConfig = new HelperConfig();
        config = helperConfig.getNetworkConfig();
        owner = config.account;

        DeployDiamond deployScript = new DeployDiamond();
        DeployDiamond.DeployedCore memory deployed = deployScript.run();

        diamond = Diamond(payable(deployed.diamond));
        cutFacet = DiamondCutFacet(deployed.cutFacet);
        loupeFacet = DiamondLoupeFacet(deployed.loupeFacet);
        ownershipFacet = OwnershipFacet(deployed.ownershipFacet);

        diamondCut = IDiamondCut(address(diamond));
        loupe = IDiamondLoupe(address(diamond));
        ownership = IERC173(address(diamond));
    }

    function testDeploymentWiresExpectedFacetAddresses() public view {
        assertEq(loupe.facetAddress(IDiamondCut.diamondCut.selector), address(cutFacet));
        assertEq(loupe.facetAddress(IDiamondLoupe.facets.selector), address(loupeFacet));
        assertEq(loupe.facetAddress(IERC173.owner.selector), address(ownershipFacet));
    }

    function testDeploymentReturnsNonZeroCodeBearingAddresses() public view {
        _assertDeployedAddress(address(diamond));
        _assertDeployedAddress(address(cutFacet));
        _assertDeployedAddress(address(loupeFacet));
        _assertDeployedAddress(address(ownershipFacet));
    }

    function testLoupeFacetAddressesContainExactlyDeployedFacets() public view {
        address[] memory facetAddresses = loupe.facetAddresses();
        assertEq(facetAddresses.length, 3, "unexpected facet count");
        assertTrue(_containsAddress(facetAddresses, address(cutFacet)), "missing cut facet");
        assertTrue(_containsAddress(facetAddresses, address(loupeFacet)), "missing loupe facet");
        assertTrue(_containsAddress(facetAddresses, address(ownershipFacet)), "missing ownership facet");
    }

    function testLoupeReportsThreeFacetAddresses() public view {
        address[] memory facetAddresses = loupe.facetAddresses();
        assertEq(facetAddresses.length, 3);
    }

    function testSupportsRequiredInterfaces() public view {
        assertTrue(IERC165(address(diamond)).supportsInterface(type(IERC165).interfaceId));
        assertTrue(IERC165(address(diamond)).supportsInterface(type(IDiamondCut).interfaceId));
        assertTrue(IERC165(address(diamond)).supportsInterface(type(IDiamondLoupe).interfaceId));
        assertTrue(IERC165(address(diamond)).supportsInterface(type(IERC173).interfaceId));
    }

    function testOwnerStartsAsDeployerAndCanTransferOwnership() public {
        assertEq(ownership.owner(), owner);

        vm.prank(owner);
        ownership.transferOwnership(user);
        assertEq(ownership.owner(), user);
    }

    function testUnauthorizedDiamondCutReverts() public {
        IDiamondCut.FacetCut[] memory cut = new IDiamondCut.FacetCut[](0);
        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(LibDiamond.LibDiamond__NotContractOwner.selector, user, owner));
        diamondCut.diamondCut(cut, address(0), "");
    }

    function _assertDeployedAddress(address deployedAddress) internal view {
        assertTrue(deployedAddress != address(0), "deployed address is zero");
        assertGt(deployedAddress.code.length, 0, "deployed address has no code");
    }

    function _containsAddress(address[] memory values, address expected) internal pure returns (bool) {
        for (uint256 i; i < values.length; i++) {
            if (values[i] == expected) {
                return true;
            }
        }
        return false;
    }
}
