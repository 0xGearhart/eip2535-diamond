// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {IDiamondLoupe} from "src/interfaces/IDiamondLoupe.sol";
import {LibDiamond} from "src/libraries/LibDiamond.sol";

/// @title Diamond Loupe Facet
/// @author 0xGearhart
/// @notice Provides ERC-2535 introspection methods for facet and selector discovery.
/// @dev Reads selector/facet mappings from `LibDiamond` storage without mutating state.
contract DiamondLoupeFacet is IDiamondLoupe, IERC165 {
    /// @notice Returns all facets with their corresponding function selectors.
    /// @return facets_ Array of facet descriptors containing facet address and selector list.
    function facets() external view override returns (Facet[] memory facets_) {
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();
        uint256 numFacets = ds.s_facetAddresses.length;
        facets_ = new Facet[](numFacets);

        for (uint256 i; i < numFacets; i++) {
            address facetAddress_ = ds.s_facetAddresses[i];
            facets_[i].facetAddress = facetAddress_;
            facets_[i].functionSelectors = ds.s_facetFunctionSelectors[facetAddress_].functionSelectors;
        }
    }

    /// @notice Returns all function selectors supported by a given facet address.
    /// @param _facet Facet address to inspect.
    /// @return facetFunctionSelectors_ Selector array currently registered to `_facet`.
    function facetFunctionSelectors(address _facet)
        external
        view
        override
        returns (bytes4[] memory facetFunctionSelectors_)
    {
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();
        facetFunctionSelectors_ = ds.s_facetFunctionSelectors[_facet].functionSelectors;
    }

    /// @notice Returns all facet addresses currently registered in the diamond.
    /// @return facetAddresses_ Array of facet addresses.
    function facetAddresses() external view override returns (address[] memory facetAddresses_) {
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();
        facetAddresses_ = ds.s_facetAddresses;
    }

    /// @notice Returns the facet address that implements a given function selector.
    /// @param _functionSelector Selector to resolve.
    /// @return facetAddress_ Facet address for `_functionSelector`, or `address(0)` if missing.
    function facetAddress(bytes4 _functionSelector) external view override returns (address facetAddress_) {
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();
        facetAddress_ = ds.s_selectorToFacetAndPosition[_functionSelector].facetAddress;
    }

    /// @notice Returns whether an interface id is marked as supported by the diamond.
    /// @param _interfaceId Interface id to query.
    /// @return supported_ True if supported, false otherwise.
    function supportsInterface(bytes4 _interfaceId) external view override returns (bool supported_) {
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();
        supported_ = ds.s_supportedInterfaces[_interfaceId];
    }
}
