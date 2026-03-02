// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

/// @title ERC-173 Contract Ownership Interface
/// @author 0xGearhart
/// @notice Standard interface for basic ownership in contracts.
interface IERC173 {
    /// @notice Emitted when ownership is transferred.
    /// @param previousOwner Previous owner address.
    /// @param newOwner New owner address.
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /// @notice Returns the current owner.
    /// @return owner_ Current owner address.
    function owner() external view returns (address owner_);

    /// @notice Transfers ownership to a new owner.
    /// @param _newOwner Address to receive ownership.
    function transferOwnership(address _newOwner) external;
}
