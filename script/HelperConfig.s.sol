// SPDX-License-Identifier: MIT

import {Script, console2} from "forge-std/Script.sol";

pragma solidity 0.8.33;

contract CodeConstants {
    string constant TOKEN_NAME = "";
    string constant TOKEN_SYMBOL = "";
    uint256 constant INITIAL_SUPPLY = 1 ether;

    // default local account and key for signing
    address constant ANVIL_DEFAULT_ACCOUNT = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
    uint256 constant ANVIL_DEFAULT_KEY = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;

    uint256 constant LOCAL_CHAIN_ID = 31_337;
    uint256 constant ETH_MAINNET_CHAIN_ID = 1;
    uint256 constant ETH_SEPOLIA_CHAIN_ID = 11_155_111;
    uint256 constant ARB_MAINNET_CHAIN_ID = 42_161;
    uint256 constant ARB_SEPOLIA_CHAIN_ID = 421_614;
    uint256 constant BASE_MAINNET_CHAIN_ID = 8453;
    uint256 constant BASE_SEPOLIA_CHAIN_ID = 84_532;
}

contract HelperConfig is Script, CodeConstants {
    error HelperConfig__InvalidNetwork(uint256 chainId);

    struct NetworkConfig {
        address account;
    }

    NetworkConfig public localNetworkConfig;
    mapping(uint256 chainid => NetworkConfig) public networkConfigs;

    constructor() {
        networkConfigs[ETH_MAINNET_CHAIN_ID] = _getEthMainnetConfig();
        networkConfigs[ETH_SEPOLIA_CHAIN_ID] = _getEthSepoliaConfig();
        networkConfigs[ARB_MAINNET_CHAIN_ID] = _getArbMainnetConfig();
        networkConfigs[ARB_SEPOLIA_CHAIN_ID] = _getArbSepoliaConfig();
        networkConfigs[BASE_MAINNET_CHAIN_ID] = _getBaseMainnetConfig();
        networkConfigs[BASE_SEPOLIA_CHAIN_ID] = _getBaseSepoliaConfig();
    }

    function getNetworkConfig() public returns (NetworkConfig memory) {
        if (block.chainid == LOCAL_CHAIN_ID) {
            return _getOrCreateLocalConfig();
        } else if (networkConfigs[block.chainid].account != address(0)) {
            return networkConfigs[block.chainid];
        } else {
            revert HelperConfig__InvalidNetwork(block.chainid);
        }
    }

    function _getEthMainnetConfig() public view returns (NetworkConfig memory) {
        return NetworkConfig({account: vm.envAddress("DEFAULT_KEY_ADDRESS")});
    }

    function _getEthSepoliaConfig() public view returns (NetworkConfig memory) {
        return NetworkConfig({account: vm.envAddress("DEFAULT_KEY_ADDRESS")});
    }

    function _getArbMainnetConfig() public view returns (NetworkConfig memory) {
        return NetworkConfig({account: vm.envAddress("DEFAULT_KEY_ADDRESS")});
    }

    function _getArbSepoliaConfig() public view returns (NetworkConfig memory) {
        return NetworkConfig({account: vm.envAddress("DEFAULT_KEY_ADDRESS")});
    }

    function _getBaseMainnetConfig() public view returns (NetworkConfig memory) {
        return NetworkConfig({account: vm.envAddress("DEFAULT_KEY_ADDRESS")});
    }

    function _getBaseSepoliaConfig() public view returns (NetworkConfig memory) {
        return NetworkConfig({account: vm.envAddress("DEFAULT_KEY_ADDRESS")});
    }

    function _getOrCreateLocalConfig() public returns (NetworkConfig memory) {
        // if mocks are already deployed, return struct
        if (localNetworkConfig.account != address(0)) {
            return localNetworkConfig;
        }
        // // otherwise, deploy mocks and save struct
        // console2.log("Deploying mocks...");
        // vm.startBroadcast(ANVIL_DEFAULT_ACCOUNT);
        // vm.stopBroadcast();

        localNetworkConfig = NetworkConfig({account: ANVIL_DEFAULT_ACCOUNT});

        return localNetworkConfig;
    }
}
