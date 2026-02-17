// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {LibDiamond} from "src/libraries/LibDiamond.sol";
import {LibERC20Storage} from "src/libraries/LibERC20Storage.sol";

contract ERC20Facet is IERC20Metadata {
    error ERC20Facet__TransferFromZeroAddress();
    error ERC20Facet__TransferToZeroAddress();
    error ERC20Facet__ApproveFromZeroAddress();
    error ERC20Facet__ApproveToZeroAddress();
    error ERC20Facet__MintToZeroAddress();
    error ERC20Facet__BurnFromZeroAddress();
    error ERC20Facet__InsufficientBalance(uint256 balance, uint256 needed);
    error ERC20Facet__InsufficientAllowance(uint256 allowance, uint256 needed);

    function name() external view returns (string memory) {
        return LibERC20Storage.erc20Storage().s_name;
    }

    function symbol() external view returns (string memory) {
        return LibERC20Storage.erc20Storage().s_symbol;
    }

    function decimals() external view returns (uint8) {
        return LibERC20Storage.erc20Storage().s_decimals;
    }

    function totalSupply() external view returns (uint256) {
        return LibERC20Storage.erc20Storage().s_totalSupply;
    }

    function balanceOf(address account) external view returns (uint256) {
        return LibERC20Storage.erc20Storage().s_balances[account];
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }

    function allowance(address owner, address spender) external view returns (uint256) {
        return LibERC20Storage.erc20Storage().s_allowances[owner][spender];
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        _approve(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        _spendAllowance(from, msg.sender, amount);
        _transfer(from, to, amount);
        return true;
    }

    function mint(address to, uint256 amount) external returns (bool) {
        LibDiamond.enforceIsContractOwner();
        _mint(to, amount);
        return true;
    }

    function burn(uint256 amount) external returns (bool) {
        _burn(msg.sender, amount);
        return true;
    }

    function burnFrom(address from, uint256 amount) external returns (bool) {
        _spendAllowance(from, msg.sender, amount);
        _burn(from, amount);
        return true;
    }

    function _transfer(address from, address to, uint256 amount) internal {
        if (from == address(0)) {
            revert ERC20Facet__TransferFromZeroAddress();
        }
        if (to == address(0)) {
            revert ERC20Facet__TransferToZeroAddress();
        }

        LibERC20Storage.ERC20Storage storage es = LibERC20Storage.erc20Storage();
        uint256 fromBalance = es.s_balances[from];
        if (fromBalance < amount) {
            revert ERC20Facet__InsufficientBalance(fromBalance, amount);
        }

        unchecked {
            es.s_balances[from] = fromBalance - amount;
        }
        es.s_balances[to] += amount;
        emit Transfer(from, to, amount);
    }

    function _approve(address owner, address spender, uint256 amount) internal {
        if (owner == address(0)) {
            revert ERC20Facet__ApproveFromZeroAddress();
        }
        if (spender == address(0)) {
            revert ERC20Facet__ApproveToZeroAddress();
        }

        LibERC20Storage.erc20Storage().s_allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function _spendAllowance(address owner, address spender, uint256 amount) internal {
        LibERC20Storage.ERC20Storage storage es = LibERC20Storage.erc20Storage();
        uint256 currentAllowance = es.s_allowances[owner][spender];
        if (currentAllowance < type(uint256).max) {
            if (currentAllowance < amount) {
                revert ERC20Facet__InsufficientAllowance(currentAllowance, amount);
            }
            unchecked {
                es.s_allowances[owner][spender] = currentAllowance - amount;
            }
            emit Approval(owner, spender, es.s_allowances[owner][spender]);
        }
    }

    function _mint(address to, uint256 amount) internal {
        if (to == address(0)) {
            revert ERC20Facet__MintToZeroAddress();
        }

        LibERC20Storage.ERC20Storage storage es = LibERC20Storage.erc20Storage();
        es.s_totalSupply += amount;
        es.s_balances[to] += amount;
        emit Transfer(address(0), to, amount);
    }

    function _burn(address from, uint256 amount) internal {
        if (from == address(0)) {
            revert ERC20Facet__BurnFromZeroAddress();
        }

        LibERC20Storage.ERC20Storage storage es = LibERC20Storage.erc20Storage();
        uint256 fromBalance = es.s_balances[from];
        if (fromBalance < amount) {
            revert ERC20Facet__InsufficientBalance(fromBalance, amount);
        }

        unchecked {
            es.s_balances[from] = fromBalance - amount;
        }
        es.s_totalSupply -= amount;
        emit Transfer(from, address(0), amount);
    }
}
