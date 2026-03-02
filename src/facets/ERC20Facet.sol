// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {LibDiamond} from "src/libraries/LibDiamond.sol";
import {LibERC20Storage} from "src/libraries/LibERC20Storage.sol";

/// @title ERC-20 Facet
/// @author 0xGearhart
/// @notice Provides ERC-20 functionality for the diamond, plus owner mint and burn operations.
/// @dev Uses `LibERC20Storage` for namespaced token state.
contract ERC20Facet is IERC20Metadata {
    error ERC20Facet__TransferFromZeroAddress();
    error ERC20Facet__TransferToZeroAddress();
    error ERC20Facet__ApproveFromZeroAddress();
    error ERC20Facet__ApproveToZeroAddress();
    error ERC20Facet__MintToZeroAddress();
    error ERC20Facet__BurnFromZeroAddress();
    error ERC20Facet__InsufficientBalance(uint256 balance, uint256 needed);
    error ERC20Facet__InsufficientAllowance(uint256 allowance, uint256 needed);

    /// @notice Returns the token name.
    /// @return Token name string.
    function name() external view returns (string memory) {
        return LibERC20Storage.erc20Storage().s_name;
    }

    /// @notice Returns the token symbol.
    /// @return Token symbol string.
    function symbol() external view returns (string memory) {
        return LibERC20Storage.erc20Storage().s_symbol;
    }

    /// @notice Returns the token decimals.
    /// @return Number of decimals used for display.
    function decimals() external view returns (uint8) {
        return LibERC20Storage.erc20Storage().s_decimals;
    }

    /// @notice Returns total token supply.
    /// @return Total token supply.
    function totalSupply() external view returns (uint256) {
        return LibERC20Storage.erc20Storage().s_totalSupply;
    }

    /// @notice Returns the token balance for an account.
    /// @param account Account to query.
    /// @return Account token balance.
    function balanceOf(address account) external view returns (uint256) {
        return LibERC20Storage.erc20Storage().s_balances[account];
    }

    /// @notice Transfers tokens from caller to recipient.
    /// @param to Recipient address.
    /// @param amount Transfer amount.
    /// @return Always returns true on success.
    function transfer(address to, uint256 amount) external returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }

    /// @notice Returns allowance from owner to spender.
    /// @param owner Token owner.
    /// @param spender Approved spender.
    /// @return Remaining allowance amount.
    function allowance(address owner, address spender) external view returns (uint256) {
        return LibERC20Storage.erc20Storage().s_allowances[owner][spender];
    }

    /// @notice Sets allowance for spender from caller balance.
    /// @param spender Spender to approve.
    /// @param amount Allowance amount.
    /// @return Always returns true on success.
    function approve(address spender, uint256 amount) external returns (bool) {
        _approve(msg.sender, spender, amount);
        return true;
    }

    /// @notice Transfers tokens from `from` to `to` using caller allowance.
    /// @param from Address to transfer from.
    /// @param to Recipient address.
    /// @param amount Transfer amount.
    /// @return Always returns true on success.
    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        _spendAllowance(from, msg.sender, amount);
        _transfer(from, to, amount);
        return true;
    }

    /// @notice Mints tokens to an account.
    /// @dev Only callable by the current diamond owner.
    /// @param to Recipient address.
    /// @param amount Amount to mint.
    /// @return Always returns true on success.
    function mint(address to, uint256 amount) external returns (bool) {
        LibDiamond.enforceIsContractOwner();
        _mint(to, amount);
        return true;
    }

    /// @notice Burns tokens from the caller balance.
    /// @param amount Amount to burn.
    /// @return Always returns true on success.
    function burn(uint256 amount) external returns (bool) {
        _burn(msg.sender, amount);
        return true;
    }

    /// @notice Burns tokens from an account using the caller's allowance.
    /// @param from Address to burn from.
    /// @param amount Amount to burn.
    /// @return Always returns true on success.
    function burnFrom(address from, uint256 amount) external returns (bool) {
        _spendAllowance(from, msg.sender, amount);
        _burn(from, amount);
        return true;
    }

    /// @notice Moves tokens between accounts.
    /// @dev Reverts on zero-address endpoints or insufficient balance.
    /// @param from Sender address.
    /// @param to Recipient address.
    /// @param amount Transfer amount.
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

    /// @notice Sets allowance from owner to spender.
    /// @dev Reverts on zero owner or zero spender.
    /// @param owner Token owner approving allowance.
    /// @param spender Allowed spender.
    /// @param amount Allowance amount.
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

    /// @notice Consumes allowance for a spender unless allowance is max uint256.
    /// @dev Mirrors common ERC-20 behavior where max uint256 is treated as infinite allowance.
    /// @param owner Token owner whose allowance is being consumed.
    /// @param spender Spender consuming allowance.
    /// @param amount Amount to consume.
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

    /// @notice Mints tokens to an account and increases total supply.
    /// @dev Reverts if `to` is zero address.
    /// @param to Recipient address.
    /// @param amount Amount to mint.
    function _mint(address to, uint256 amount) internal {
        if (to == address(0)) {
            revert ERC20Facet__MintToZeroAddress();
        }

        LibERC20Storage.ERC20Storage storage es = LibERC20Storage.erc20Storage();
        es.s_totalSupply += amount;
        es.s_balances[to] += amount;
        emit Transfer(address(0), to, amount);
    }

    /// @notice Burns tokens from an account and decreases total supply.
    /// @dev Reverts on zero address or insufficient balance.
    /// @param from Address to burn from.
    /// @param amount Amount to burn.
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
