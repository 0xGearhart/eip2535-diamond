// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {IERC173} from "src/interfaces/IERC173.sol";
import {LibDiamond} from "src/libraries/LibDiamond.sol";

/// @title Ownership Facet
/// @author 0xGearhart
/// @notice Exposes ownership read/transfer operations for the diamond.
/// @dev Uses `LibDiamond` ownership state and owner-gated checks.
contract OwnershipFacet is IERC173 {
    /// @notice Thrown when attempting to transfer ownership to the zero address.
    error OwnershipFacet__NewOwnerIsZeroAddress();

    /// @inheritdoc IERC173
    /// @notice Returns the current diamond owner.
    function owner() external view override returns (address owner_) {
        owner_ = LibDiamond.contractOwner();
    }

    /// @inheritdoc IERC173
    /// @notice Transfers diamond ownership to `_newOwner`.
    /// @dev Reverts when `_newOwner` is zero.
    function transferOwnership(address _newOwner) external override {
        LibDiamond.enforceIsContractOwner();
        if (_newOwner == address(0)) {
            revert OwnershipFacet__NewOwnerIsZeroAddress();
        }
        LibDiamond.setContractOwner(_newOwner);
    }

    /// @notice Renounces ownership by setting owner to `address(0)`.
    /// @dev Only callable by the current owner.
    function renounceOwnership() external {
        LibDiamond.enforceIsContractOwner();
        LibDiamond.setContractOwner(address(0));
    }
}
