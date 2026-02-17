// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {IERC173} from "src/interfaces/IERC173.sol";
import {LibDiamond} from "src/libraries/LibDiamond.sol";

contract OwnershipFacet is IERC173 {
    error OwnershipFacet__NewOwnerIsZeroAddress();

    function owner() external view override returns (address owner_) {
        owner_ = LibDiamond.contractOwner();
    }

    function transferOwnership(address _newOwner) external override {
        LibDiamond.enforceIsContractOwner();
        if (_newOwner == address(0)) {
            revert OwnershipFacet__NewOwnerIsZeroAddress();
        }
        LibDiamond.setContractOwner(_newOwner);
    }

    function renounceOwnership() external {
        LibDiamond.enforceIsContractOwner();
        LibDiamond.setContractOwner(address(0));
    }
}
