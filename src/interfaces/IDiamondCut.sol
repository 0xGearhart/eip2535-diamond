// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

/// @title ERC-2535 Diamond Cut Interface
/// @author 0xGearhart
/// @notice Defines the upgrade surface for adding, replacing, and removing facet selectors.
interface IDiamondCut {
    /// @notice Enumerates the supported facet cut operations.
    enum FacetCutAction {
        Add,
        Replace,
        Remove
    }

    /// @notice Describes one facet modification in a diamond cut.
    /// @param facetAddress Facet address used for the action (must be zero for remove).
    /// @param action Operation type: add, replace, or remove.
    /// @param functionSelectors Selectors to apply the action to.
    struct FacetCut {
        address facetAddress;
        FacetCutAction action;
        bytes4[] functionSelectors;
    }

    /// @notice Emitted when a diamond cut is executed.
    /// @param _diamondCut Array of facet modifications that were applied.
    /// @param _init Optional initializer address used after cut execution.
    /// @param _calldata Initialization calldata executed via delegatecall on `_init`.
    event DiamondCut(FacetCut[] _diamondCut, address _init, bytes _calldata);

    /// @notice Executes a diamond cut.
    /// @param _diamondCut Array of facet modifications to apply.
    /// @param _init Optional initializer address for post-cut initialization.
    /// @param _calldata Initialization calldata passed to `_init`.
    function diamondCut(FacetCut[] calldata _diamondCut, address _init, bytes calldata _calldata) external;
}
