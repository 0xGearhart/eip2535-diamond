// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {Test} from "forge-std/Test.sol";
import {DeployDiamond} from "script/DeployDiamond.s.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {IDiamondLoupe} from "src/interfaces/IDiamondLoupe.sol";
import {Handler} from "test/invariant/Handler.t.sol";

contract InvariantsTest is StdInvariant, Test {
    IERC20 internal token;
    IDiamondLoupe internal loupe;
    Handler internal handler;

    function setUp() public {
        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory config = helperConfig.getNetworkConfig();

        DeployDiamond deployScript = new DeployDiamond();
        DeployDiamond.DeployedCore memory deployed = deployScript.run();

        token = IERC20(deployed.diamond);
        loupe = IDiamondLoupe(deployed.diamond);

        address[] memory actors = new address[](5);
        actors[0] = makeAddr("actor1");
        actors[1] = makeAddr("actor2");
        actors[2] = makeAddr("actor3");
        actors[3] = makeAddr("actor4");
        actors[4] = makeAddr("actor5");
        handler = new Handler(deployed.diamond, config.account, actors);

        targetContract(address(handler));

        bytes4[] memory selectors = new bytes4[](8);
        selectors[0] = handler.transfer.selector;
        selectors[1] = handler.approve.selector;
        selectors[2] = handler.transferFrom.selector;
        selectors[3] = handler.mint.selector;
        selectors[4] = handler.burn.selector;
        selectors[5] = handler.burnFrom.selector;
        selectors[6] = handler.cutAddMockSelector.selector;
        selectors[7] = handler.cutRemoveMockSelector.selector;
        targetSelector(FuzzSelector({addr: address(handler), selectors: selectors}));
    }

    function invariant_totalSupplyEqualsTrackedHolderBalances() public view {
        uint256 trackedLength = handler.trackedHoldersLength();
        uint256 summedBalances;
        for (uint256 i; i < trackedLength; i++) {
            summedBalances += token.balanceOf(handler.trackedHolderAt(i));
        }
        assertEq(summedBalances, token.totalSupply());
    }

    function invariant_loupeViewsStayInternallyConsistent() public view {
        IDiamondLoupe.Facet[] memory facets = loupe.facets();
        address[] memory facetAddresses = loupe.facetAddresses();

        assertEq(facets.length, facetAddresses.length);

        for (uint256 i; i < facets.length; i++) {
            address facetAddress = facets[i].facetAddress;
            assertTrue(facetAddress != address(0));
            assertTrue(_containsAddress(facetAddresses, facetAddress));

            bytes4[] memory facetSelectors = facets[i].functionSelectors;
            bytes4[] memory selectorsFromFacetAddress = loupe.facetFunctionSelectors(facetAddress);
            assertEq(facetSelectors.length, selectorsFromFacetAddress.length);
            assertGt(facetSelectors.length, 0);

            for (uint256 j; j < facetSelectors.length; j++) {
                bytes4 selector = facetSelectors[j];
                assertEq(loupe.facetAddress(selector), facetAddress);
                assertTrue(_containsSelector(selectorsFromFacetAddress, selector));
            }
        }
    }

    function _containsAddress(address[] memory values, address target) internal pure returns (bool) {
        for (uint256 i; i < values.length; i++) {
            if (values[i] == target) {
                return true;
            }
        }
        return false;
    }

    function _containsSelector(bytes4[] memory values, bytes4 target) internal pure returns (bool) {
        for (uint256 i; i < values.length; i++) {
            if (values[i] == target) {
                return true;
            }
        }
        return false;
    }
}
