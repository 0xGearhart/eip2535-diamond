// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {LibERC20Storage} from "src/libraries/LibERC20Storage.sol";

/// @title Diamond Initializer for ERC-20 State
/// @author 0xGearhart
/// @notice Initializes ERC-20 metadata and optional initial mint for the diamond.
/// @dev Intended to be called via `diamondCut` initializer delegatecall.
contract DiamondInit {
    /// @notice Thrown when initialization is attempted more than once.
    error DiamondInit__AlreadyInitialized();

    /// @notice Thrown when `initialSupply_ > 0` and `initialHolder_` is zero.
    error DiamondInit__InitialHolderIsZeroAddress();

    /// @notice ERC-20 transfer event emitted during initial mint.
    event Transfer(address indexed from, address indexed to, uint256 value);

    /// @notice Initializes ERC-20 metadata and optional initial supply.
    /// @dev Enforces one-time initialization via `s_initialized`.
    /// @param name_ Token name.
    /// @param symbol_ Token symbol.
    /// @param decimals_ Token decimals.
    /// @param initialHolder_ Recipient of initial supply, when non-zero supply is used.
    /// @param initialSupply_ Initial total supply to mint.
    function init(
        string calldata name_,
        string calldata symbol_,
        uint8 decimals_,
        address initialHolder_,
        uint256 initialSupply_
    ) external {
        LibERC20Storage.ERC20Storage storage es = LibERC20Storage.erc20Storage();
        if (es.s_initialized) {
            revert DiamondInit__AlreadyInitialized();
        }

        es.s_name = name_;
        es.s_symbol = symbol_;
        es.s_decimals = decimals_;
        es.s_initialized = true;

        if (initialSupply_ == 0) {
            return;
        }
        if (initialHolder_ == address(0)) {
            revert DiamondInit__InitialHolderIsZeroAddress();
        }

        es.s_totalSupply = initialSupply_;
        es.s_balances[initialHolder_] = initialSupply_;
        emit Transfer(address(0), initialHolder_, initialSupply_);
    }
}
