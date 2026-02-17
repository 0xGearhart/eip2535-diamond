// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {Test} from "forge-std/Test.sol";
import {DeployDiamond} from "script/DeployDiamond.s.sol";
import {CodeConstants, HelperConfig} from "script/HelperConfig.s.sol";
import {Diamond} from "src/Diamond.sol";
import {DiamondCutFacet} from "src/facets/DiamondCutFacet.sol";
import {DiamondLoupeFacet} from "src/facets/DiamondLoupeFacet.sol";
import {ERC20Facet} from "src/facets/ERC20Facet.sol";
import {OwnershipFacet} from "src/facets/OwnershipFacet.sol";
import {IDiamondCut} from "src/interfaces/IDiamondCut.sol";
import {IDiamondLoupe} from "src/interfaces/IDiamondLoupe.sol";
import {IERC173} from "src/interfaces/IERC173.sol";

contract DeployDiamondTest is Test, CodeConstants {
    Diamond internal diamond;
    DiamondCutFacet internal cutFacet;
    DiamondLoupeFacet internal loupeFacet;
    OwnershipFacet internal ownershipFacet;
    ERC20Facet internal erc20Facet;
    address internal init;

    IDiamondCut internal diamondCut;
    IDiamondLoupe internal loupe;
    IERC173 internal ownership;
    IERC20 internal erc20;
    IERC20Metadata internal erc20Metadata;

    HelperConfig.NetworkConfig internal config;

    function setUp() public {
        HelperConfig helperConfig = new HelperConfig();
        config = helperConfig.getNetworkConfig();

        DeployDiamond deployScript = new DeployDiamond();
        DeployDiamond.DeployedCore memory deployed = deployScript.run();

        diamond = Diamond(payable(deployed.diamond));
        cutFacet = DiamondCutFacet(deployed.cutFacet);
        loupeFacet = DiamondLoupeFacet(deployed.loupeFacet);
        ownershipFacet = OwnershipFacet(deployed.ownershipFacet);
        erc20Facet = ERC20Facet(deployed.erc20Facet);
        init = deployed.init;

        diamondCut = IDiamondCut(address(diamond));
        loupe = IDiamondLoupe(address(diamond));
        ownership = IERC173(address(diamond));
        erc20 = IERC20(address(diamond));
        erc20Metadata = IERC20Metadata(address(diamond));
    }

    function testDeploymentWiresExpectedFacetAddresses() public view {
        assertEq(loupe.facetAddress(IDiamondCut.diamondCut.selector), address(cutFacet));
        assertEq(loupe.facetAddress(IDiamondLoupe.facets.selector), address(loupeFacet));
        assertEq(loupe.facetAddress(IERC173.owner.selector), address(ownershipFacet));
        assertEq(loupe.facetAddress(IERC20.transfer.selector), address(erc20Facet));
        assertEq(loupe.facetAddress(ERC20Facet.mint.selector), address(erc20Facet));
    }

    function testDeploymentReturnsNonZeroCodeBearingAddresses() public view {
        _assertDeployedAddress(address(diamond));
        _assertDeployedAddress(address(cutFacet));
        _assertDeployedAddress(address(loupeFacet));
        _assertDeployedAddress(address(ownershipFacet));
        _assertDeployedAddress(address(erc20Facet));
        _assertDeployedAddress(init);
    }

    function testLoupeFacetAddressesContainExactlyDeployedFacets() public view {
        address[] memory facetAddresses = loupe.facetAddresses();
        assertEq(facetAddresses.length, 4, "unexpected facet count");
        assertTrue(_containsAddress(facetAddresses, address(cutFacet)), "missing cut facet");
        assertTrue(_containsAddress(facetAddresses, address(loupeFacet)), "missing loupe facet");
        assertTrue(_containsAddress(facetAddresses, address(ownershipFacet)), "missing ownership facet");
        assertTrue(_containsAddress(facetAddresses, address(erc20Facet)), "missing erc20 facet");
    }

    function testDeploymentInitializesERC20State() public view {
        assertEq(erc20Metadata.name(), TOKEN_NAME);
        assertEq(erc20Metadata.symbol(), TOKEN_SYMBOL);
        assertEq(erc20Metadata.decimals(), TOKEN_DECIMALS);

        assertEq(erc20.totalSupply(), INITIAL_SUPPLY);
        assertEq(erc20.balanceOf(config.account), INITIAL_SUPPLY);
    }

    function _assertDeployedAddress(address deployedAddress) internal view {
        assertTrue(deployedAddress != address(0), "deployed address is zero");
        assertGt(deployedAddress.code.length, 0, "deployed address has no code");
    }

    function _containsAddress(address[] memory values, address expected) internal pure returns (bool) {
        for (uint256 i; i < values.length; i++) {
            if (values[i] == expected) {
                return true;
            }
        }
        return false;
    }
}
