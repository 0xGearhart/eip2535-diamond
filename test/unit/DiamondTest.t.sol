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

contract DiamondTest is Test {
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

    function testDiamondCutAllowsNonEmptyCalldataWhenInitIsZero() public {
        IDiamondCut.FacetCut[] memory cut = new IDiamondCut.FacetCut[](0);

        vm.prank(owner);
        diamondCut.diamondCut(cut, address(0), hex"1234");

        // The call should succeed and leave ownership unchanged.
        assertEq(ownership.owner(), owner);
    }

    function testCoreSelectorsResolveToFacetsNotDiamond() public view {
        _assertSelectorResolvedToFacet(IDiamondCut.diamondCut.selector, address(cutFacet));

        _assertSelectorResolvedToFacet(IDiamondLoupe.facets.selector, address(loupeFacet));
        _assertSelectorResolvedToFacet(IDiamondLoupe.facetFunctionSelectors.selector, address(loupeFacet));
        _assertSelectorResolvedToFacet(IDiamondLoupe.facetAddresses.selector, address(loupeFacet));
        _assertSelectorResolvedToFacet(IDiamondLoupe.facetAddress.selector, address(loupeFacet));
        _assertSelectorResolvedToFacet(IERC165.supportsInterface.selector, address(loupeFacet));

        _assertSelectorResolvedToFacet(IERC173.owner.selector, address(ownershipFacet));
        _assertSelectorResolvedToFacet(IERC173.transferOwnership.selector, address(ownershipFacet));
        _assertSelectorResolvedToFacet(OwnershipFacet.renounceOwnership.selector, address(ownershipFacet));
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

    function testTransferOwnershipToZeroAddressReverts() public {
        vm.prank(owner);
        vm.expectRevert(OwnershipFacet.OwnershipFacet__NewOwnerIsZeroAddress.selector);
        ownership.transferOwnership(address(0));
    }

    function testOwnerCanRenounceOwnership() public {
        vm.prank(owner);
        OwnershipFacet(address(diamond)).renounceOwnership();

        assertEq(ownership.owner(), address(0));
    }

    function testUnauthorizedDiamondCutReverts() public {
        IDiamondCut.FacetCut[] memory cut = new IDiamondCut.FacetCut[](0);
        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(LibDiamond.LibDiamond__NotContractOwner.selector, user, owner));
        diamondCut.diamondCut(cut, address(0), "");
    }

    function _assertSelectorResolvedToFacet(bytes4 selector, address expectedFacet) internal view {
        address resolvedFacet = loupe.facetAddress(selector);
        assertEq(resolvedFacet, expectedFacet, "selector resolved to unexpected facet");
        assertTrue(resolvedFacet != address(diamond), "selector resolved to diamond");
    }
}
