// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {LibERC20Storage} from "src/libraries/LibERC20Storage.sol";

contract DiamondInit {
    error DiamondInit__AlreadyInitialized();
    error DiamondInit__InitialHolderIsZeroAddress();

    event Transfer(address indexed from, address indexed to, uint256 value);

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
