// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {IDiamondCut} from "src/interfaces/IDiamondCut.sol";
import {LibDiamond} from "src/libraries/LibDiamond.sol";

contract DiamondCutFacet is IDiamondCut {
    function diamondCut(FacetCut[] calldata _diamondCut, address _init, bytes calldata _calldata) external override {
        LibDiamond.enforceIsContractOwner();
        LibDiamond.diamondCut(_diamondCut, _init, _calldata);
    }
}
