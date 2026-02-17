// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

library LibERC20Storage {
    bytes32 internal constant ERC20_STORAGE_POSITION = keccak256("diamond.standard.erc20.storage");

    struct ERC20Storage {
        string s_name;
        string s_symbol;
        uint8 s_decimals;
        uint256 s_totalSupply;
        mapping(address account => uint256 balance) s_balances;
        mapping(address owner => mapping(address spender => uint256 allowance)) s_allowances;
        bool s_initialized;
    }

    function erc20Storage() internal pure returns (ERC20Storage storage es) {
        bytes32 position = ERC20_STORAGE_POSITION;
        assembly {
            es.slot := position
        }
    }
}
