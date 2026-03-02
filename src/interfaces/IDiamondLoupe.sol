// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

/// @title ERC-2535 Diamond Loupe Interface
/// @author 0xGearhart
/// @notice Defines view methods for facet and selector introspection.
interface IDiamondLoupe {
    /// @notice Represents one facet and its registered selectors.
    /// @param facetAddress Facet address.
    /// @param functionSelectors Selectors currently mapped to `facetAddress`.
    struct Facet {
        address facetAddress;
        bytes4[] functionSelectors;
    }

    /// @notice Returns all facets and their selectors.
    /// @return facets_ Array of facet descriptors.
    function facets() external view returns (Facet[] memory facets_);

    /// @notice Returns all selectors for a specific facet address.
    /// @param _facet Facet address to inspect.
    /// @return facetFunctionSelectors_ Selector array mapped to `_facet`.
    function facetFunctionSelectors(address _facet) external view returns (bytes4[] memory facetFunctionSelectors_);

    /// @notice Returns all facet addresses in the diamond.
    /// @return facetAddresses_ Array of registered facet addresses.
    function facetAddresses() external view returns (address[] memory facetAddresses_);

    /// @notice Returns the facet address that implements a selector.
    /// @param _functionSelector Selector to resolve.
    /// @return facetAddress_ Resolved facet address, or `address(0)` if missing.
    function facetAddress(bytes4 _functionSelector) external view returns (address facetAddress_);
}
