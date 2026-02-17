// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {Test} from "forge-std/Test.sol";
import {DiamondInit} from "src/upgradeInitializers/DiamondInit.sol";

contract DiamondInitTest is Test {
    function testInitWithZeroSupplyReturnsEarlyAndSetsInitialized() public {
        DiamondInit init = new DiamondInit();

        init.init("Token", "TKN", 18, address(0), 0);

        vm.expectRevert(DiamondInit.DiamondInit__AlreadyInitialized.selector);
        init.init("Token2", "TK2", 18, address(this), 1);
    }

    function testInitWithNonZeroSupplyAndZeroHolderReverts() public {
        DiamondInit init = new DiamondInit();

        vm.expectRevert(DiamondInit.DiamondInit__InitialHolderIsZeroAddress.selector);
        init.init("Token", "TKN", 18, address(0), 1);
    }
}
