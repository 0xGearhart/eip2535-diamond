// SPDX-License-Identifier: MIT

import {CodeConstants, HelperConfig} from "./HelperConfig.s.sol";
import {Script} from "forge-std/Script.sol";

pragma solidity 0.8.33;

contract DeployDiamond is Script, CodeConstants {
    function run() external {
        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory config = helperConfig.getNetworkConfig();

        vm.startBroadcast(config.account);

        vm.stopBroadcast();
    }
}
