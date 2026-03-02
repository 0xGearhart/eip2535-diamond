// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {IDiamondCut} from "src/interfaces/IDiamondCut.sol";

/// @title Diamond Core Library
/// @author 0xGearhart
/// @notice Implements selector table management, ownership checks, and cut initialization logic.
/// @dev Stores all diamond core state at a fixed namespaced storage slot.
library LibDiamond {
    /// @notice Storage slot for diamond core state.
    bytes32 internal constant DIAMOND_STORAGE_POSITION = keccak256("diamond.standard.diamond.storage");

    error LibDiamond__NotContractOwner(address sender, address owner);
    error LibDiamond__NoSelectorsProvidedForFacet(address facetAddress);
    error LibDiamond__CannotAddSelectorsToZeroAddress();
    error LibDiamond__NoBytecodeAtAddress(address account, string message);
    error LibDiamond__CannotAddFunctionToDiamondThatAlreadyExists(bytes4 selector);
    error LibDiamond__CannotReplaceFunctionsFromFacetWithZeroAddress();
    error LibDiamond__CannotReplaceImmutableFunction(bytes4 selector);
    error LibDiamond__CannotReplaceFunctionWithTheSameFunctionFromTheSameFacet(bytes4 selector);
    error LibDiamond__CannotReplaceFunctionThatDoesNotExist(bytes4 selector);
    error LibDiamond__RemoveFacetAddressMustBeZeroAddress(address facetAddress);
    error LibDiamond__CannotRemoveFunctionThatDoesNotExist(bytes4 selector);
    error LibDiamond__CannotRemoveImmutableFunction(bytes4 selector);
    error LibDiamond__IncorrectFacetCutAction(uint8 action);
    error LibDiamond__CalldataIsEmptyButInitIsNotZeroAddress();
    error LibDiamond__InitializationFunctionReverted(address initAddress, bytes reason);

    /// @notice Selector lookup entry containing facet and selector index in that facet.
    struct FacetAddressAndPosition {
        address facetAddress;
        uint96 functionSelectorPosition;
    }

    /// @notice Selector list and facet index metadata for a facet address.
    struct FacetFunctionSelectors {
        bytes4[] functionSelectors;
        uint256 facetAddressPosition;
    }

    /// @notice Diamond core storage layout.
    struct DiamondStorage {
        mapping(bytes4 selector => FacetAddressAndPosition facetAddressAndSelectorPosition) s_selectorToFacetAndPosition;
        mapping(address facetAddress => FacetFunctionSelectors facetFunctionSelectors) s_facetFunctionSelectors;
        address[] s_facetAddresses;
        mapping(bytes4 interfaceId => bool) s_supportedInterfaces;
        address s_contractOwner;
    }

    /// @notice Returns the namespaced diamond storage pointer.
    /// @dev Uses a fixed storage slot to avoid collisions across facets.
    /// @return ds Diamond storage struct reference.
    function diamondStorage() internal pure returns (DiamondStorage storage ds) {
        bytes32 position = DIAMOND_STORAGE_POSITION;
        assembly {
            ds.slot := position
        }
    }

    /// @notice Sets the diamond contract owner.
    /// @dev Emits `OwnershipTransferred`.
    /// @param _newOwner New owner address.
    function setContractOwner(address _newOwner) internal {
        DiamondStorage storage ds = diamondStorage();
        address previousOwner = ds.s_contractOwner;
        ds.s_contractOwner = _newOwner;
        emit OwnershipTransferred(previousOwner, _newOwner);
    }

    /// @notice Returns the current contract owner.
    /// @dev Reads owner from the diamond namespaced storage slot.
    /// @return owner_ Current owner address.
    function contractOwner() internal view returns (address owner_) {
        owner_ = diamondStorage().s_contractOwner;
    }

    /// @notice Reverts unless the caller is the current owner.
    /// @dev Shared guard used by owner-gated facet entrypoints.
    function enforceIsContractOwner() internal view {
        address owner_ = contractOwner();
        if (msg.sender != owner_) {
            revert LibDiamond__NotContractOwner(msg.sender, owner_);
        }
    }

    /// @notice Applies one or more facet modifications to the selector table.
    /// @dev Processes each cut in order, emits `DiamondCut`, then runs optional init delegatecall.
    /// @param _diamondCut Array of facet cut operations.
    /// @param _init Optional initializer target address for delegatecall.
    /// @param _calldata Initialization calldata passed to `_init`.
    function diamondCut(IDiamondCut.FacetCut[] memory _diamondCut, address _init, bytes memory _calldata) internal {
        for (uint256 facetIndex; facetIndex < _diamondCut.length; facetIndex++) {
            IDiamondCut.FacetCutAction action = _diamondCut[facetIndex].action;
            if (action == IDiamondCut.FacetCutAction.Add) {
                addFunctions(_diamondCut[facetIndex].facetAddress, _diamondCut[facetIndex].functionSelectors);
            } else if (action == IDiamondCut.FacetCutAction.Replace) {
                replaceFunctions(_diamondCut[facetIndex].facetAddress, _diamondCut[facetIndex].functionSelectors);
            } else if (action == IDiamondCut.FacetCutAction.Remove) {
                removeFunctions(_diamondCut[facetIndex].facetAddress, _diamondCut[facetIndex].functionSelectors);
            } else {
                revert LibDiamond__IncorrectFacetCutAction(uint8(action));
            }
        }

        emit IDiamondCut.DiamondCut(_diamondCut, _init, _calldata);
        initializeDiamondCut(_init, _calldata);
    }

    /// @notice Adds selectors to a facet.
    /// @dev Registers the facet first when it is not already present.
    /// @param _facetAddress Facet receiving new selectors.
    /// @param _functionSelectors Selectors to add.
    function addFunctions(address _facetAddress, bytes4[] memory _functionSelectors) internal {
        if (_functionSelectors.length == 0) {
            revert LibDiamond__NoSelectorsProvidedForFacet(_facetAddress);
        }
        if (_facetAddress == address(0)) {
            revert LibDiamond__CannotAddSelectorsToZeroAddress();
        }

        DiamondStorage storage ds = diamondStorage();
        uint96 selectorPosition = uint96(ds.s_facetFunctionSelectors[_facetAddress].functionSelectors.length);

        if (selectorPosition == 0) {
            addFacet(ds, _facetAddress);
        }

        for (uint256 selectorIndex; selectorIndex < _functionSelectors.length; selectorIndex++) {
            bytes4 selector = _functionSelectors[selectorIndex];
            address oldFacetAddress = ds.s_selectorToFacetAndPosition[selector].facetAddress;
            if (oldFacetAddress != address(0)) {
                revert LibDiamond__CannotAddFunctionToDiamondThatAlreadyExists(selector);
            }
            addFunction(ds, selector, selectorPosition, _facetAddress);
            selectorPosition++;
        }
    }

    /// @notice Replaces existing selector implementations with a new facet.
    /// @dev Prevents replacing with same facet, replacing missing selectors, or replacing immutable selectors.
    /// @param _facetAddress New facet for selector implementations.
    /// @param _functionSelectors Selectors to replace.
    function replaceFunctions(address _facetAddress, bytes4[] memory _functionSelectors) internal {
        if (_functionSelectors.length == 0) {
            revert LibDiamond__NoSelectorsProvidedForFacet(_facetAddress);
        }
        if (_facetAddress == address(0)) {
            revert LibDiamond__CannotReplaceFunctionsFromFacetWithZeroAddress();
        }

        DiamondStorage storage ds = diamondStorage();
        uint96 selectorPosition = uint96(ds.s_facetFunctionSelectors[_facetAddress].functionSelectors.length);

        if (selectorPosition == 0) {
            addFacet(ds, _facetAddress);
        }

        for (uint256 selectorIndex; selectorIndex < _functionSelectors.length; selectorIndex++) {
            bytes4 selector = _functionSelectors[selectorIndex];
            address oldFacetAddress = ds.s_selectorToFacetAndPosition[selector].facetAddress;

            if (oldFacetAddress == _facetAddress) {
                revert LibDiamond__CannotReplaceFunctionWithTheSameFunctionFromTheSameFacet(selector);
            }
            if (oldFacetAddress == address(0)) {
                revert LibDiamond__CannotReplaceFunctionThatDoesNotExist(selector);
            }
            if (oldFacetAddress == address(this)) {
                revert LibDiamond__CannotReplaceImmutableFunction(selector);
            }

            removeFunction(ds, oldFacetAddress, selector);
            addFunction(ds, selector, selectorPosition, _facetAddress);
            selectorPosition++;
        }
    }

    /// @notice Removes selectors from the diamond.
    /// @dev `_facetAddress` must be zero by ERC-2535 convention for removals.
    /// @param _facetAddress Must be zero address for remove operations.
    /// @param _functionSelectors Selectors to remove.
    function removeFunctions(address _facetAddress, bytes4[] memory _functionSelectors) internal {
        if (_functionSelectors.length == 0) {
            revert LibDiamond__NoSelectorsProvidedForFacet(_facetAddress);
        }
        if (_facetAddress != address(0)) {
            revert LibDiamond__RemoveFacetAddressMustBeZeroAddress(_facetAddress);
        }

        DiamondStorage storage ds = diamondStorage();
        for (uint256 selectorIndex; selectorIndex < _functionSelectors.length; selectorIndex++) {
            bytes4 selector = _functionSelectors[selectorIndex];
            address oldFacetAddress = ds.s_selectorToFacetAndPosition[selector].facetAddress;
            removeFunction(ds, oldFacetAddress, selector);
        }
    }

    /// @notice Registers a new facet address in facet address storage.
    /// @dev Reverts if `_facetAddress` has no deployed bytecode.
    /// @param ds Diamond storage pointer.
    /// @param _facetAddress Facet to register.
    function addFacet(DiamondStorage storage ds, address _facetAddress) internal {
        enforceHasContractCode(_facetAddress, "LibDiamond: New facet has no code");
        ds.s_facetFunctionSelectors[_facetAddress].facetAddressPosition = ds.s_facetAddresses.length;
        ds.s_facetAddresses.push(_facetAddress);
    }

    /// @notice Appends a selector mapping to a facet.
    /// @dev Stores both selector->facet mapping and facet selector list metadata.
    /// @param ds Diamond storage pointer.
    /// @param _selector Selector to map.
    /// @param _selectorPosition Position in facet selector array.
    /// @param _facetAddress Facet implementing `_selector`.
    function addFunction(
        DiamondStorage storage ds,
        bytes4 _selector,
        uint96 _selectorPosition,
        address _facetAddress
    ) internal {
        ds.s_selectorToFacetAndPosition[_selector].functionSelectorPosition = _selectorPosition;
        ds.s_facetFunctionSelectors[_facetAddress].functionSelectors.push(_selector);
        ds.s_selectorToFacetAndPosition[_selector].facetAddress = _facetAddress;
    }

    /// @notice Removes a selector mapping from a facet and compacts facet storage.
    /// @dev Uses swap-and-pop for selectors and facet addresses to keep arrays dense.
    /// @param ds Diamond storage pointer.
    /// @param _facetAddress Facet currently mapped to `_selector`.
    /// @param _selector Selector to remove.
    function removeFunction(DiamondStorage storage ds, address _facetAddress, bytes4 _selector) internal {
        if (_facetAddress == address(0)) {
            revert LibDiamond__CannotRemoveFunctionThatDoesNotExist(_selector);
        }
        if (_facetAddress == address(this)) {
            revert LibDiamond__CannotRemoveImmutableFunction(_selector);
        }

        uint256 selectorPosition = ds.s_selectorToFacetAndPosition[_selector].functionSelectorPosition;
        uint256 lastSelectorPosition = ds.s_facetFunctionSelectors[_facetAddress].functionSelectors.length - 1;

        if (selectorPosition != lastSelectorPosition) {
            bytes4 lastSelector = ds.s_facetFunctionSelectors[_facetAddress].functionSelectors[lastSelectorPosition];
            ds.s_facetFunctionSelectors[_facetAddress].functionSelectors[selectorPosition] = lastSelector;
            ds.s_selectorToFacetAndPosition[lastSelector].functionSelectorPosition = uint96(selectorPosition);
        }

        ds.s_facetFunctionSelectors[_facetAddress].functionSelectors.pop();
        delete ds.s_selectorToFacetAndPosition[_selector];

        if (lastSelectorPosition == 0) {
            uint256 lastFacetAddressPosition = ds.s_facetAddresses.length - 1;
            uint256 facetAddressPosition = ds.s_facetFunctionSelectors[_facetAddress].facetAddressPosition;

            if (facetAddressPosition != lastFacetAddressPosition) {
                address lastFacetAddress = ds.s_facetAddresses[lastFacetAddressPosition];
                ds.s_facetAddresses[facetAddressPosition] = lastFacetAddress;
                ds.s_facetFunctionSelectors[lastFacetAddress].facetAddressPosition = facetAddressPosition;
            }

            ds.s_facetAddresses.pop();
            delete ds.s_facetFunctionSelectors[_facetAddress].facetAddressPosition;
        }
    }

    /// @notice Executes optional post-cut initialization delegatecall.
    /// @dev If `_init` is non-zero, `_calldata` must be non-empty. Reverts wrapping delegatecall error bytes.
    /// @param _init Initializer target address.
    /// @param _calldata Calldata to delegatecall on `_init`.
    function initializeDiamondCut(address _init, bytes memory _calldata) internal {
        if (_init == address(0)) {
            return;
        } else {
            if (_calldata.length == 0) {
                revert LibDiamond__CalldataIsEmptyButInitIsNotZeroAddress();
            }
            if (_init != address(this)) {
                enforceHasContractCode(_init, "LibDiamond: _init address has no code");
            }
            (bool success, bytes memory error) = _init.delegatecall(_calldata);
            if (!success) {
                revert LibDiamond__InitializationFunctionReverted(_init, error);
            }
        }
    }

    /// @notice Ensures an address has deployed bytecode.
    /// @dev Used to guard facet/init addresses before selector wiring or delegatecall.
    /// @param _contract Address to validate.
    /// @param _errorMessage Error message to include in revert.
    function enforceHasContractCode(address _contract, string memory _errorMessage) internal view {
        uint256 contractSize;
        assembly {
            contractSize := extcodesize(_contract)
        }
        if (contractSize == 0) {
            revert LibDiamond__NoBytecodeAtAddress(_contract, _errorMessage);
        }
    }

    /// @notice Emitted when diamond ownership changes.
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
}
