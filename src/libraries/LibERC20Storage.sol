// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

/// @title ERC-20 Diamond Storage Library
/// @author 0xGearhart
/// @notice Provides namespaced storage access for ERC-20 facet state.
library LibERC20Storage {
    /// @notice Storage slot for ERC-20 state in the diamond.
    bytes32 internal constant ERC20_STORAGE_POSITION = keccak256("diamond.standard.erc20.storage");

    /// @notice Persistent ERC-20 state layout.
    struct ERC20Storage {
        string s_name;
        string s_symbol;
        uint8 s_decimals;
        uint256 s_totalSupply;
        mapping(address account => uint256 balance) s_balances;
        mapping(address owner => mapping(address spender => uint256 allowance)) s_allowances;
        bool s_initialized;
    }

    /// @notice Returns a pointer to ERC-20 storage.
    /// @dev Uses a dedicated slot so ERC-20 state does not collide with diamond core storage.
    /// @return es ERC-20 storage struct at the namespaced slot.
    function erc20Storage() internal pure returns (ERC20Storage storage es) {
        bytes32 position = ERC20_STORAGE_POSITION;
        assembly {
            es.slot := position
        }
    }
}
