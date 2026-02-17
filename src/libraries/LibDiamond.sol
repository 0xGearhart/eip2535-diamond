// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {IDiamondCut} from "src/interfaces/IDiamondCut.sol";

library LibDiamond {
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

    struct FacetAddressAndPosition {
        address facetAddress;
        uint96 functionSelectorPosition;
    }

    struct FacetFunctionSelectors {
        bytes4[] functionSelectors;
        uint256 facetAddressPosition;
    }

    struct DiamondStorage {
        mapping(bytes4 selector => FacetAddressAndPosition facetAddressAndSelectorPosition) selectorToFacetAndPosition;
        mapping(address facetAddress => FacetFunctionSelectors facetFunctionSelectors) facetFunctionSelectors;
        address[] facetAddresses;
        mapping(bytes4 interfaceId => bool) supportedInterfaces;
        address contractOwner;
    }

    function diamondStorage() internal pure returns (DiamondStorage storage ds) {
        bytes32 position = DIAMOND_STORAGE_POSITION;
        assembly {
            ds.slot := position
        }
    }

    function setContractOwner(address _newOwner) internal {
        DiamondStorage storage ds = diamondStorage();
        address previousOwner = ds.contractOwner;
        ds.contractOwner = _newOwner;
        emit OwnershipTransferred(previousOwner, _newOwner);
    }

    function contractOwner() internal view returns (address owner_) {
        owner_ = diamondStorage().contractOwner;
    }

    function enforceIsContractOwner() internal view {
        address owner_ = contractOwner();
        if (msg.sender != owner_) {
            revert LibDiamond__NotContractOwner(msg.sender, owner_);
        }
    }

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

    function addFunctions(address _facetAddress, bytes4[] memory _functionSelectors) internal {
        if (_functionSelectors.length == 0) {
            revert LibDiamond__NoSelectorsProvidedForFacet(_facetAddress);
        }
        if (_facetAddress == address(0)) {
            revert LibDiamond__CannotAddSelectorsToZeroAddress();
        }

        DiamondStorage storage ds = diamondStorage();
        uint96 selectorPosition = uint96(ds.facetFunctionSelectors[_facetAddress].functionSelectors.length);

        if (selectorPosition == 0) {
            addFacet(ds, _facetAddress);
        }

        for (uint256 selectorIndex; selectorIndex < _functionSelectors.length; selectorIndex++) {
            bytes4 selector = _functionSelectors[selectorIndex];
            address oldFacetAddress = ds.selectorToFacetAndPosition[selector].facetAddress;
            if (oldFacetAddress != address(0)) {
                revert LibDiamond__CannotAddFunctionToDiamondThatAlreadyExists(selector);
            }
            addFunction(ds, selector, selectorPosition, _facetAddress);
            selectorPosition++;
        }
    }

    function replaceFunctions(address _facetAddress, bytes4[] memory _functionSelectors) internal {
        if (_functionSelectors.length == 0) {
            revert LibDiamond__NoSelectorsProvidedForFacet(_facetAddress);
        }
        if (_facetAddress == address(0)) {
            revert LibDiamond__CannotReplaceFunctionsFromFacetWithZeroAddress();
        }

        DiamondStorage storage ds = diamondStorage();
        uint96 selectorPosition = uint96(ds.facetFunctionSelectors[_facetAddress].functionSelectors.length);

        if (selectorPosition == 0) {
            addFacet(ds, _facetAddress);
        }

        for (uint256 selectorIndex; selectorIndex < _functionSelectors.length; selectorIndex++) {
            bytes4 selector = _functionSelectors[selectorIndex];
            address oldFacetAddress = ds.selectorToFacetAndPosition[selector].facetAddress;

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
            address oldFacetAddress = ds.selectorToFacetAndPosition[selector].facetAddress;
            removeFunction(ds, oldFacetAddress, selector);
        }
    }

    function addFacet(DiamondStorage storage ds, address _facetAddress) internal {
        enforceHasContractCode(_facetAddress, "LibDiamond: New facet has no code");
        ds.facetFunctionSelectors[_facetAddress].facetAddressPosition = ds.facetAddresses.length;
        ds.facetAddresses.push(_facetAddress);
    }

    function addFunction(
        DiamondStorage storage ds,
        bytes4 _selector,
        uint96 _selectorPosition,
        address _facetAddress
    ) internal {
        ds.selectorToFacetAndPosition[_selector].functionSelectorPosition = _selectorPosition;
        ds.facetFunctionSelectors[_facetAddress].functionSelectors.push(_selector);
        ds.selectorToFacetAndPosition[_selector].facetAddress = _facetAddress;
    }

    function removeFunction(DiamondStorage storage ds, address _facetAddress, bytes4 _selector) internal {
        if (_facetAddress == address(0)) {
            revert LibDiamond__CannotRemoveFunctionThatDoesNotExist(_selector);
        }
        if (_facetAddress == address(this)) {
            revert LibDiamond__CannotRemoveImmutableFunction(_selector);
        }

        uint256 selectorPosition = ds.selectorToFacetAndPosition[_selector].functionSelectorPosition;
        uint256 lastSelectorPosition = ds.facetFunctionSelectors[_facetAddress].functionSelectors.length - 1;

        if (selectorPosition != lastSelectorPosition) {
            bytes4 lastSelector = ds.facetFunctionSelectors[_facetAddress].functionSelectors[lastSelectorPosition];
            ds.facetFunctionSelectors[_facetAddress].functionSelectors[selectorPosition] = lastSelector;
            ds.selectorToFacetAndPosition[lastSelector].functionSelectorPosition = uint96(selectorPosition);
        }

        ds.facetFunctionSelectors[_facetAddress].functionSelectors.pop();
        delete ds.selectorToFacetAndPosition[_selector];

        if (lastSelectorPosition == 0) {
            uint256 lastFacetAddressPosition = ds.facetAddresses.length - 1;
            uint256 facetAddressPosition = ds.facetFunctionSelectors[_facetAddress].facetAddressPosition;

            if (facetAddressPosition != lastFacetAddressPosition) {
                address lastFacetAddress = ds.facetAddresses[lastFacetAddressPosition];
                ds.facetAddresses[facetAddressPosition] = lastFacetAddress;
                ds.facetFunctionSelectors[lastFacetAddress].facetAddressPosition = facetAddressPosition;
            }

            ds.facetAddresses.pop();
            delete ds.facetFunctionSelectors[_facetAddress].facetAddressPosition;
        }
    }

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

    function enforceHasContractCode(address _contract, string memory _errorMessage) internal view {
        uint256 contractSize;
        assembly {
            contractSize := extcodesize(_contract)
        }
        if (contractSize == 0) {
            revert LibDiamond__NoBytecodeAtAddress(_contract, _errorMessage);
        }
    }

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
}
