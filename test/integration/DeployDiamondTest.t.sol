// SPDX-License-Identifier: MIT

import {DeployDiamond} from "../../script/DeployDiamond.s.sol";
import {CodeConstants, HelperConfig} from "../../script/HelperConfig.s.sol";
import {Test} from "forge-std/Test.sol";

pragma solidity ^0.8.27;

contract DeployTest is Test, CodeConstants {
    HelperConfig helperConfig;
    HelperConfig.NetworkConfig config;
    DeployDiamond deployer;

    function setUp() public {
        helperConfig = new HelperConfig();
        config = helperConfig.getNetworkConfig();
        deployer = new DeployDiamond();
    }

    function testDiamondDeployedCorrectly() public view {}
}
