// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {IDiamondCut} from "src/interfaces/IDiamondCut.sol";
import {IDiamondLoupe} from "src/interfaces/IDiamondLoupe.sol";
import {IERC173} from "src/interfaces/IERC173.sol";
import {LibDiamond} from "src/libraries/LibDiamond.sol";

/// @title ERC-2535 Diamond Proxy
/// @author 0xGearhart
/// @notice Routes external function calls to facet contracts using delegatecall.
/// @dev Keeps callable business/admin logic in facets and limits this contract to proxy plumbing.
contract Diamond {
    // Keep callable business/admin logic in facets only.
    // This contract should remain proxy plumbing (constructor/fallback/receive),
    // so selector introspection and upgrade history stay facet-centric.
    /// @notice Deploys the diamond and wires the initial DiamondCut facet selector.
    /// @dev Registers ERC165, IDiamondCut, IDiamondLoupe, and IERC173 interface support.
    /// @param _contractOwner Initial contract owner with upgrade authority.
    /// @param _diamondCutFacet Facet address that implements `diamondCut`.
    constructor(address _contractOwner, address _diamondCutFacet) payable {
        LibDiamond.setContractOwner(_contractOwner);

        IDiamondCut.FacetCut[] memory cut = new IDiamondCut.FacetCut[](1);
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = IDiamondCut.diamondCut.selector;
        cut[0] = IDiamondCut.FacetCut({
            facetAddress: _diamondCutFacet, action: IDiamondCut.FacetCutAction.Add, functionSelectors: selectors
        });
        LibDiamond.diamondCut(cut, address(0), "");

        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();
        ds.s_supportedInterfaces[type(IERC165).interfaceId] = true;
        ds.s_supportedInterfaces[type(IDiamondCut).interfaceId] = true;
        ds.s_supportedInterfaces[type(IDiamondLoupe).interfaceId] = true;
        ds.s_supportedInterfaces[type(IERC173).interfaceId] = true;
    }

    /// @notice Fallback entrypoint that dispatches calls to facets by function selector.
    /// @dev Reverts if no facet is registered for `msg.sig`.
    fallback() external payable {
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();
        address facet = ds.s_selectorToFacetAndPosition[msg.sig].facetAddress;
        if (facet == address(0)) {
            revert("Diamond: Function does not exist");
        }

        assembly {
            calldatacopy(0, 0, calldatasize())
            let result := delegatecall(gas(), facet, 0, calldatasize(), 0, 0)
            returndatacopy(0, 0, returndatasize())
            switch result
            case 0 {
                revert(0, returndatasize())
            }
            default {
                return(0, returndatasize())
            }
        }
    }

    /// @notice Accepts plain ETH transfers to the diamond.
    receive() external payable {}
}
