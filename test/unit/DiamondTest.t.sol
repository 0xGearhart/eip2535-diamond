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
import {MockInitReverter, MockInitSuccess} from "test/mocks/MockInitializers.sol";
import {MockFacetAdd, MockFacetReplaceV1, MockFacetReplaceV2} from "test/mocks/MockUpgradeFacets.sol";

interface IAddedFunction {
    function addedFunction() external view returns (uint256);
}

interface IReplacedFunction {
    function replacedFunction() external view returns (uint256);
}

interface ISharedValue {
    function setSharedValue(uint256 newValue) external;
    function getSharedValue() external view returns (uint256);
}

contract DiamondTest is Test {
    Diamond internal diamond;
    DiamondCutFacet internal cutFacet;
    DiamondLoupeFacet internal loupeFacet;
    OwnershipFacet internal ownershipFacet;

    IDiamondCut internal diamondCut;
    IDiamondLoupe internal loupe;
    IERC173 internal ownership;

    MockFacetAdd internal addFacet;
    MockFacetReplaceV1 internal replaceFacetV1;
    MockFacetReplaceV2 internal replaceFacetV2;

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

        addFacet = new MockFacetAdd();
        replaceFacetV1 = new MockFacetReplaceV1();
        replaceFacetV2 = new MockFacetReplaceV2();
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

    function testLoupeFacetsIncludesExpectedSelectorsPerFacet() public {
        IDiamondLoupe.Facet[] memory allFacets = loupe.facets();
        assertEq(allFacets.length, 3);

        bytes4[] memory cutSelectors = loupe.facetFunctionSelectors(address(cutFacet));
        assertEq(cutSelectors.length, 1);
        assertEq(cutSelectors[0], IDiamondCut.diamondCut.selector);

        bytes4[] memory loupeSelectors = loupe.facetFunctionSelectors(address(loupeFacet));
        assertEq(loupeSelectors.length, 5);
        _assertContainsSelector(loupeSelectors, IDiamondLoupe.facets.selector);
        _assertContainsSelector(loupeSelectors, IDiamondLoupe.facetFunctionSelectors.selector);
        _assertContainsSelector(loupeSelectors, IDiamondLoupe.facetAddresses.selector);
        _assertContainsSelector(loupeSelectors, IDiamondLoupe.facetAddress.selector);
        _assertContainsSelector(loupeSelectors, IERC165.supportsInterface.selector);

        bytes4[] memory ownershipSelectors = loupe.facetFunctionSelectors(address(ownershipFacet));
        assertEq(ownershipSelectors.length, 3);
        _assertContainsSelector(ownershipSelectors, IERC173.owner.selector);
        _assertContainsSelector(ownershipSelectors, IERC173.transferOwnership.selector);
        _assertContainsSelector(ownershipSelectors, OwnershipFacet.renounceOwnership.selector);
    }

    function testLoupeUnknownFacetAndSelectorReturnEmptyValues() public {
        address unknownFacet = makeAddr("unknownFacet");
        assertEq(loupe.facetFunctionSelectors(unknownFacet).length, 0);
        assertEq(loupe.facetAddress(bytes4(keccak256("doesNotExist()"))), address(0));
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

    function testUpgradeAddSelectorAndExecute() public {
        bytes4[] memory selectors = _singleSelectorArray(MockFacetAdd.addedFunction.selector);
        IDiamondCut.FacetCut[] memory cut = _singleCut(address(addFacet), IDiamondCut.FacetCutAction.Add, selectors);

        vm.prank(owner);
        diamondCut.diamondCut(cut, address(0), "");

        assertEq(loupe.facetAddress(MockFacetAdd.addedFunction.selector), address(addFacet));
        assertEq(IAddedFunction(address(diamond)).addedFunction(), 111);
    }

    function testUpgradeReplaceSelectorAndPreserveState() public {
        bytes4[] memory addSelectors = new bytes4[](3);
        addSelectors[0] = MockFacetReplaceV1.replacedFunction.selector;
        addSelectors[1] = MockFacetReplaceV1.setSharedValue.selector;
        addSelectors[2] = MockFacetReplaceV1.getSharedValue.selector;

        IDiamondCut.FacetCut[] memory addCut =
            _singleCut(address(replaceFacetV1), IDiamondCut.FacetCutAction.Add, addSelectors);
        vm.prank(owner);
        diamondCut.diamondCut(addCut, address(0), "");

        ISharedValue(address(diamond)).setSharedValue(42);
        assertEq(IReplacedFunction(address(diamond)).replacedFunction(), 1);
        assertEq(ISharedValue(address(diamond)).getSharedValue(), 42);

        bytes4[] memory replaceSelectors = new bytes4[](2);
        replaceSelectors[0] = MockFacetReplaceV2.replacedFunction.selector;
        replaceSelectors[1] = MockFacetReplaceV2.getSharedValue.selector;
        IDiamondCut.FacetCut[] memory replaceCut =
            _singleCut(address(replaceFacetV2), IDiamondCut.FacetCutAction.Replace, replaceSelectors);

        vm.prank(owner);
        diamondCut.diamondCut(replaceCut, address(0), "");

        assertEq(loupe.facetAddress(MockFacetReplaceV2.replacedFunction.selector), address(replaceFacetV2));
        assertEq(IReplacedFunction(address(diamond)).replacedFunction(), 2);
        assertEq(ISharedValue(address(diamond)).getSharedValue(), 43);
    }

    function testUpgradeRemoveSelectorAndCallsRevert() public {
        bytes4[] memory selectors = _singleSelectorArray(MockFacetAdd.addedFunction.selector);
        IDiamondCut.FacetCut[] memory addCut = _singleCut(address(addFacet), IDiamondCut.FacetCutAction.Add, selectors);

        vm.prank(owner);
        diamondCut.diamondCut(addCut, address(0), "");
        assertEq(IAddedFunction(address(diamond)).addedFunction(), 111);

        IDiamondCut.FacetCut[] memory removeCut = _singleCut(address(0), IDiamondCut.FacetCutAction.Remove, selectors);

        vm.prank(owner);
        diamondCut.diamondCut(removeCut, address(0), "");

        assertEq(loupe.facetAddress(MockFacetAdd.addedFunction.selector), address(0));
        vm.expectRevert(bytes("Diamond: Function does not exist"));
        IAddedFunction(address(diamond)).addedFunction();
    }

    function testDiamondCutAddDuplicateSelectorReverts() public {
        bytes4[] memory selectors = _singleSelectorArray(IERC173.owner.selector);
        IDiamondCut.FacetCut[] memory cut = _singleCut(address(addFacet), IDiamondCut.FacetCutAction.Add, selectors);

        vm.prank(owner);
        vm.expectRevert(
            abi.encodeWithSelector(
                LibDiamond.LibDiamond__CannotAddFunctionToDiamondThatAlreadyExists.selector, IERC173.owner.selector
            )
        );
        diamondCut.diamondCut(cut, address(0), "");
    }

    function testDiamondCutReplaceMissingSelectorReverts() public {
        bytes4[] memory selectors = _singleSelectorArray(MockFacetAdd.addedFunction.selector);
        IDiamondCut.FacetCut[] memory cut =
            _singleCut(address(replaceFacetV2), IDiamondCut.FacetCutAction.Replace, selectors);

        vm.prank(owner);
        vm.expectRevert(
            abi.encodeWithSelector(
                LibDiamond.LibDiamond__CannotReplaceFunctionThatDoesNotExist.selector,
                MockFacetAdd.addedFunction.selector
            )
        );
        diamondCut.diamondCut(cut, address(0), "");
    }

    function testDiamondCutReplaceWithSameFacetReverts() public {
        bytes4[] memory selectors = _singleSelectorArray(MockFacetReplaceV1.replacedFunction.selector);
        IDiamondCut.FacetCut[] memory addCut =
            _singleCut(address(replaceFacetV1), IDiamondCut.FacetCutAction.Add, selectors);

        vm.prank(owner);
        diamondCut.diamondCut(addCut, address(0), "");

        IDiamondCut.FacetCut[] memory replaceCut =
            _singleCut(address(replaceFacetV1), IDiamondCut.FacetCutAction.Replace, selectors);

        vm.prank(owner);
        vm.expectRevert(
            abi.encodeWithSelector(
                LibDiamond.LibDiamond__CannotReplaceFunctionWithTheSameFunctionFromTheSameFacet.selector,
                MockFacetReplaceV1.replacedFunction.selector
            )
        );
        diamondCut.diamondCut(replaceCut, address(0), "");
    }

    function testDiamondCutRemoveWithNonZeroFacetAddressReverts() public {
        bytes4[] memory selectors = _singleSelectorArray(MockFacetAdd.addedFunction.selector);
        IDiamondCut.FacetCut[] memory cut = _singleCut(address(addFacet), IDiamondCut.FacetCutAction.Remove, selectors);

        vm.prank(owner);
        vm.expectRevert(
            abi.encodeWithSelector(
                LibDiamond.LibDiamond__RemoveFacetAddressMustBeZeroAddress.selector, address(addFacet)
            )
        );
        diamondCut.diamondCut(cut, address(0), "");
    }

    function testDiamondCutRemoveMissingSelectorReverts() public {
        bytes4[] memory selectors = _singleSelectorArray(MockFacetAdd.addedFunction.selector);
        IDiamondCut.FacetCut[] memory cut = _singleCut(address(0), IDiamondCut.FacetCutAction.Remove, selectors);

        vm.prank(owner);
        vm.expectRevert(
            abi.encodeWithSelector(
                LibDiamond.LibDiamond__CannotRemoveFunctionThatDoesNotExist.selector,
                MockFacetAdd.addedFunction.selector
            )
        );
        diamondCut.diamondCut(cut, address(0), "");
    }

    function testDiamondCutNoSelectorsProvidedReverts() public {
        bytes4[] memory selectors = new bytes4[](0);
        IDiamondCut.FacetCut[] memory cut = _singleCut(address(addFacet), IDiamondCut.FacetCutAction.Add, selectors);

        vm.prank(owner);
        vm.expectRevert(
            abi.encodeWithSelector(LibDiamond.LibDiamond__NoSelectorsProvidedForFacet.selector, address(addFacet))
        );
        diamondCut.diamondCut(cut, address(0), "");
    }

    function testDiamondCutAddWithZeroFacetAddressReverts() public {
        bytes4[] memory selectors = _singleSelectorArray(MockFacetAdd.addedFunction.selector);
        IDiamondCut.FacetCut[] memory cut = _singleCut(address(0), IDiamondCut.FacetCutAction.Add, selectors);

        vm.prank(owner);
        vm.expectRevert(LibDiamond.LibDiamond__CannotAddSelectorsToZeroAddress.selector);
        diamondCut.diamondCut(cut, address(0), "");
    }

    function testDiamondCutAddWithNoCodeFacetAddressReverts() public {
        bytes4[] memory selectors = _singleSelectorArray(MockFacetAdd.addedFunction.selector);
        address noCodeFacet = makeAddr("noCodeFacet");
        IDiamondCut.FacetCut[] memory cut = _singleCut(noCodeFacet, IDiamondCut.FacetCutAction.Add, selectors);

        vm.prank(owner);
        vm.expectRevert(
            abi.encodeWithSelector(
                LibDiamond.LibDiamond__NoBytecodeAtAddress.selector, noCodeFacet, "LibDiamond: New facet has no code"
            )
        );
        diamondCut.diamondCut(cut, address(0), "");
    }

    function testDiamondCutReplaceWithZeroFacetAddressReverts() public {
        bytes4[] memory selectors = _singleSelectorArray(IERC173.owner.selector);
        IDiamondCut.FacetCut[] memory cut = _singleCut(address(0), IDiamondCut.FacetCutAction.Replace, selectors);

        vm.prank(owner);
        vm.expectRevert(LibDiamond.LibDiamond__CannotReplaceFunctionsFromFacetWithZeroAddress.selector);
        diamondCut.diamondCut(cut, address(0), "");
    }

    function testDiamondCutReplaceWithNoSelectorsReverts() public {
        bytes4[] memory selectors = new bytes4[](0);
        IDiamondCut.FacetCut[] memory cut =
            _singleCut(address(replaceFacetV2), IDiamondCut.FacetCutAction.Replace, selectors);

        vm.prank(owner);
        vm.expectRevert(
            abi.encodeWithSelector(LibDiamond.LibDiamond__NoSelectorsProvidedForFacet.selector, address(replaceFacetV2))
        );
        diamondCut.diamondCut(cut, address(0), "");
    }

    function testDiamondCutReplaceWithNoCodeFacetAddressReverts() public {
        bytes4[] memory selectors = _singleSelectorArray(IERC173.owner.selector);
        address noCodeFacet = makeAddr("noCodeFacet");
        IDiamondCut.FacetCut[] memory cut = _singleCut(noCodeFacet, IDiamondCut.FacetCutAction.Replace, selectors);

        vm.prank(owner);
        vm.expectRevert(
            abi.encodeWithSelector(
                LibDiamond.LibDiamond__NoBytecodeAtAddress.selector, noCodeFacet, "LibDiamond: New facet has no code"
            )
        );
        diamondCut.diamondCut(cut, address(0), "");
    }

    function testDiamondCutReplaceImmutableFunctionReverts() public {
        bytes4 selector = bytes4(keccak256("immutableFn()"));
        vm.store(address(diamond), _selectorToFacetSlot(selector), bytes32(uint256(uint160(address(diamond)))));

        bytes4[] memory selectors = _singleSelectorArray(selector);
        IDiamondCut.FacetCut[] memory cut =
            _singleCut(address(replaceFacetV2), IDiamondCut.FacetCutAction.Replace, selectors);

        vm.prank(owner);
        vm.expectRevert(
            abi.encodeWithSelector(LibDiamond.LibDiamond__CannotReplaceImmutableFunction.selector, selector)
        );
        diamondCut.diamondCut(cut, address(0), "");
    }

    function testDiamondCutRemoveWithNoSelectorsReverts() public {
        bytes4[] memory selectors = new bytes4[](0);
        IDiamondCut.FacetCut[] memory cut = _singleCut(address(0), IDiamondCut.FacetCutAction.Remove, selectors);

        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(LibDiamond.LibDiamond__NoSelectorsProvidedForFacet.selector, address(0)));
        diamondCut.diamondCut(cut, address(0), "");
    }

    function testDiamondCutRemoveImmutableFunctionReverts() public {
        bytes4 selector = bytes4(keccak256("immutableRemoveFn()"));
        vm.store(address(diamond), _selectorToFacetSlot(selector), bytes32(uint256(uint160(address(diamond)))));

        bytes4[] memory selectors = _singleSelectorArray(selector);
        IDiamondCut.FacetCut[] memory cut = _singleCut(address(0), IDiamondCut.FacetCutAction.Remove, selectors);

        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(LibDiamond.LibDiamond__CannotRemoveImmutableFunction.selector, selector));
        diamondCut.diamondCut(cut, address(0), "");
    }

    function testDiamondCutRemoveLastSelectorFromNonLastFacetReordersFacetAddresses() public {
        bytes4[] memory selectors = _singleSelectorArray(IDiamondCut.diamondCut.selector);
        IDiamondCut.FacetCut[] memory cut = _singleCut(address(0), IDiamondCut.FacetCutAction.Remove, selectors);

        vm.prank(owner);
        diamondCut.diamondCut(cut, address(0), "");

        address[] memory facetAddresses = loupe.facetAddresses();
        assertEq(facetAddresses.length, 2);
        assertEq(loupe.facetAddress(IDiamondCut.diamondCut.selector), address(0));
        assertTrue(!_containsAddress(facetAddresses, address(cutFacet)), "cut facet should be removed");
        assertTrue(_containsAddress(facetAddresses, address(loupeFacet)), "loupe facet should remain");
        assertTrue(_containsAddress(facetAddresses, address(ownershipFacet)), "ownership facet should remain");
    }

    function testDiamondCutInitNonZeroWithEmptyCalldataReverts() public {
        IDiamondCut.FacetCut[] memory cut = new IDiamondCut.FacetCut[](0);
        address init = address(new MockInitSuccess());

        vm.prank(owner);
        vm.expectRevert(LibDiamond.LibDiamond__CalldataIsEmptyButInitIsNotZeroAddress.selector);
        diamondCut.diamondCut(cut, init, "");
    }

    function testDiamondCutInitNoCodeAddressReverts() public {
        IDiamondCut.FacetCut[] memory cut = new IDiamondCut.FacetCut[](0);
        address init = makeAddr("noCodeInit");
        bytes memory callData = abi.encodeWithSelector(MockInitSuccess.initSetValue.selector, 7);

        vm.prank(owner);
        vm.expectRevert(
            abi.encodeWithSelector(
                LibDiamond.LibDiamond__NoBytecodeAtAddress.selector, init, "LibDiamond: _init address has no code"
            )
        );
        diamondCut.diamondCut(cut, init, callData);
    }

    function testDiamondCutInitDelegatecallFailureBubblesToWrappedError() public {
        IDiamondCut.FacetCut[] memory cut = new IDiamondCut.FacetCut[](0);
        MockInitReverter init = new MockInitReverter();
        bytes memory callData = abi.encodeWithSelector(MockInitReverter.initRevert.selector);
        bytes memory innerError = abi.encodeWithSelector(MockInitReverter.MockInitReverted.selector);

        vm.prank(owner);
        vm.expectRevert(
            abi.encodeWithSelector(
                LibDiamond.LibDiamond__InitializationFunctionReverted.selector, address(init), innerError
            )
        );
        diamondCut.diamondCut(cut, address(init), callData);
    }

    function _assertSelectorResolvedToFacet(bytes4 selector, address expectedFacet) internal view {
        address resolvedFacet = loupe.facetAddress(selector);
        assertEq(resolvedFacet, expectedFacet, "selector resolved to unexpected facet");
        assertTrue(resolvedFacet != address(diamond), "selector resolved to diamond");
    }

    function _singleSelectorArray(bytes4 selector) internal pure returns (bytes4[] memory selectors) {
        selectors = new bytes4[](1);
        selectors[0] = selector;
    }

    function _singleCut(
        address facetAddress,
        IDiamondCut.FacetCutAction action,
        bytes4[] memory selectors
    )
        internal
        pure
        returns (IDiamondCut.FacetCut[] memory cut)
    {
        cut = new IDiamondCut.FacetCut[](1);
        cut[0] = IDiamondCut.FacetCut({facetAddress: facetAddress, action: action, functionSelectors: selectors});
    }

    function _assertContainsSelector(bytes4[] memory selectors, bytes4 selector) internal {
        for (uint256 i; i < selectors.length; i++) {
            if (selectors[i] == selector) {
                return;
            }
        }
        fail("selector missing");
    }

    function _selectorToFacetSlot(bytes4 selector) internal pure returns (bytes32) {
        bytes32 diamondStoragePosition = keccak256("diamond.standard.diamond.storage");
        return keccak256(abi.encode(selector, uint256(diamondStoragePosition)));
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
