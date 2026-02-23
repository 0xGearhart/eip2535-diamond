// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {IDiamondCut} from "src/interfaces/IDiamondCut.sol";
import {LibDiamond} from "src/libraries/LibDiamond.sol";

/// @title Diamond Cut Facet
/// @author 0xGearhart
/// @notice Exposes the ERC-2535 upgrade entrypoint for adding, replacing, and removing selectors.
/// @dev Delegates cut execution to `LibDiamond` and restricts access to the current contract owner.
contract DiamondCutFacet is IDiamondCut {
    /// @notice Performs a diamond cut to add, replace, or remove facet function selectors.
    /// @dev Reverts if `msg.sender` is not the contract owner.
    /// @param _diamondCut Array of facet changes to apply.
    /// @param _init Optional initializer address used for post-cut delegatecall initialization.
    /// @param _calldata Calldata passed to `_init` during post-cut initialization.
    function diamondCut(FacetCut[] calldata _diamondCut, address _init, bytes calldata _calldata) external override {
        LibDiamond.enforceIsContractOwner();
        LibDiamond.diamondCut(_diamondCut, _init, _calldata);
    }
}
