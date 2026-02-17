// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {Test} from "forge-std/Test.sol";
import {DeployDiamond} from "script/DeployDiamond.s.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {Diamond} from "src/Diamond.sol";
import {DiamondCutFacet} from "src/facets/DiamondCutFacet.sol";
import {DiamondLoupeFacet} from "src/facets/DiamondLoupeFacet.sol";
import {ERC20Facet} from "src/facets/ERC20Facet.sol";
import {OwnershipFacet} from "src/facets/OwnershipFacet.sol";
import {IDiamondCut} from "src/interfaces/IDiamondCut.sol";
import {IDiamondLoupe} from "src/interfaces/IDiamondLoupe.sol";
import {IERC173} from "src/interfaces/IERC173.sol";
import {LibDiamond} from "src/libraries/LibDiamond.sol";
import {DiamondInit} from "src/upgradeInitializers/DiamondInit.sol";
import {MockInitReverter, MockInitSuccess} from "test/mocks/MockInitializers.sol";

contract DiamondTest is Test {
    Diamond internal diamond;
    DiamondCutFacet internal cutFacet;
    DiamondLoupeFacet internal loupeFacet;
    OwnershipFacet internal ownershipFacet;
    ERC20Facet internal erc20Facet;

    IDiamondCut internal diamondCut;
    IDiamondLoupe internal loupe;
    IERC173 internal ownership;

    address internal user = makeAddr("user");
    address internal owner;
    HelperConfig.NetworkConfig config;

    function setUp() public {
        HelperConfig helperConfig = new HelperConfig();
        config = helperConfig.getNetworkConfig();
        owner = config.account;

        DeployDiamond deployScript = new DeployDiamond();
        DeployDiamond.DeployedCore memory deployed = deployScript.run();

        diamond = Diamond(payable(deployed.diamond));
        cutFacet = DiamondCutFacet(deployed.cutFacet);
        loupeFacet = DiamondLoupeFacet(deployed.loupeFacet);
        ownershipFacet = OwnershipFacet(deployed.ownershipFacet);
        erc20Facet = ERC20Facet(deployed.erc20Facet);

        diamondCut = IDiamondCut(address(diamond));
        loupe = IDiamondLoupe(address(diamond));
        ownership = IERC173(address(diamond));
    }
}
