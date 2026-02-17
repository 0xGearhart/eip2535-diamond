// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {Test} from "forge-std/Test.sol";
import {DeployDiamond} from "script/DeployDiamond.s.sol";
import {CodeConstants, HelperConfig} from "script/HelperConfig.s.sol";
import {Diamond} from "src/Diamond.sol";
import {ERC20Facet} from "src/facets/ERC20Facet.sol";
import {LibDiamond} from "src/libraries/LibDiamond.sol";

contract ERC20FacetTest is Test, CodeConstants {
    Diamond internal diamond;
    IERC20 internal token;
    IERC20Metadata internal tokenMetadata;
    ERC20Facet internal erc20Facet;

    address internal owner;
    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");
    address internal spender = makeAddr("spender");

    function setUp() public {
        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory config = helperConfig.getNetworkConfig();
        owner = config.account;

        DeployDiamond deployScript = new DeployDiamond();
        DeployDiamond.DeployedCore memory deployed = deployScript.run();

        diamond = Diamond(payable(deployed.diamond));
        token = IERC20(address(diamond));
        tokenMetadata = IERC20Metadata(address(diamond));
        erc20Facet = ERC20Facet(address(diamond));
    }

    function testInitialStateMatchesConfig() public view {
        assertEq(tokenMetadata.name(), TOKEN_NAME);
        assertEq(tokenMetadata.symbol(), TOKEN_SYMBOL);
        assertEq(tokenMetadata.decimals(), TOKEN_DECIMALS);
        assertEq(token.totalSupply(), INITIAL_SUPPLY);
        assertEq(token.balanceOf(owner), INITIAL_SUPPLY);
    }

    function testTransferUpdatesBalances() public {
        uint256 amount = 100e18;

        vm.prank(owner);
        bool ok = token.transfer(alice, amount);
        assertTrue(ok);

        assertEq(token.balanceOf(owner), INITIAL_SUPPLY - amount);
        assertEq(token.balanceOf(alice), amount);
        assertEq(token.totalSupply(), INITIAL_SUPPLY);
    }

    function testTransferRevertsWhenBalanceTooLow() public {
        uint256 amount = 1;

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(ERC20Facet.ERC20Facet__InsufficientBalance.selector, 0, amount));
        token.transfer(bob, amount);
    }

    function testTransferRevertsToZeroAddress() public {
        vm.prank(owner);
        vm.expectRevert(ERC20Facet.ERC20Facet__TransferToZeroAddress.selector);
        token.transfer(address(0), 1);
    }

    function testApproveAndTransferFromSpendsAllowance() public {
        uint256 approveAmount = 50e18;
        uint256 spendAmount = 20e18;

        vm.prank(owner);
        assertTrue(token.approve(spender, approveAmount));
        assertEq(token.allowance(owner, spender), approveAmount);

        vm.prank(spender);
        assertTrue(token.transferFrom(owner, bob, spendAmount));

        assertEq(token.balanceOf(bob), spendAmount);
        assertEq(token.allowance(owner, spender), approveAmount - spendAmount);
    }

    function testTransferFromWithMaxAllowanceDoesNotDecrease() public {
        uint256 spendAmount = 10e18;

        vm.prank(owner);
        assertTrue(token.approve(spender, type(uint256).max));

        vm.prank(spender);
        assertTrue(token.transferFrom(owner, bob, spendAmount));

        assertEq(token.allowance(owner, spender), type(uint256).max);
        assertEq(token.balanceOf(bob), spendAmount);
    }

    function testTransferFromRevertsFromZeroAddressWithZeroAmount() public {
        vm.prank(spender);
        vm.expectRevert(ERC20Facet.ERC20Facet__TransferFromZeroAddress.selector);
        token.transferFrom(address(0), bob, 0);
    }

    function testApproveRevertsToZeroSpender() public {
        vm.prank(owner);
        vm.expectRevert(ERC20Facet.ERC20Facet__ApproveToZeroAddress.selector);
        token.approve(address(0), 1);
    }

    function testApproveRevertsFromZeroOwnerWithPrank() public {
        vm.prank(address(0));
        vm.expectRevert(ERC20Facet.ERC20Facet__ApproveFromZeroAddress.selector);
        token.approve(spender, 1);
    }

    function testMintOnlyOwner() public {
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(LibDiamond.LibDiamond__NotContractOwner.selector, alice, owner));
        erc20Facet.mint(alice, 1e18);
    }

    function testOwnerMintIncreasesSupplyAndBalance() public {
        uint256 mintAmount = 25e18;
        uint256 supplyBefore = token.totalSupply();
        uint256 balanceBefore = token.balanceOf(alice);

        vm.prank(owner);
        bool ok = erc20Facet.mint(alice, mintAmount);
        assertTrue(ok);

        assertEq(token.totalSupply(), supplyBefore + mintAmount);
        assertEq(token.balanceOf(alice), balanceBefore + mintAmount);
    }

    function testMintRevertsToZeroAddress() public {
        vm.prank(owner);
        vm.expectRevert(ERC20Facet.ERC20Facet__MintToZeroAddress.selector);
        erc20Facet.mint(address(0), 1);
    }

    function testBurnReducesSupplyAndHolderBalance() public {
        uint256 amount = 15e18;

        vm.prank(owner);
        assertTrue(token.transfer(alice, amount));

        uint256 supplyBefore = token.totalSupply();
        vm.prank(alice);
        bool ok = erc20Facet.burn(amount);
        assertTrue(ok);

        assertEq(token.balanceOf(alice), 0);
        assertEq(token.totalSupply(), supplyBefore - amount);
    }

    function testBurnRevertsWhenBalanceTooLow() public {
        uint256 amount = 1;

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(ERC20Facet.ERC20Facet__InsufficientBalance.selector, 0, amount));
        erc20Facet.burn(amount);
    }

    function testBurnFromSpendsAllowanceAndBurns() public {
        uint256 amount = 12e18;

        vm.prank(owner);
        assertTrue(token.transfer(alice, amount));

        vm.prank(alice);
        assertTrue(token.approve(spender, amount));

        uint256 supplyBefore = token.totalSupply();
        vm.prank(spender);
        bool ok = erc20Facet.burnFrom(alice, amount);
        assertTrue(ok);

        assertEq(token.balanceOf(alice), 0);
        assertEq(token.allowance(alice, spender), 0);
        assertEq(token.totalSupply(), supplyBefore - amount);
    }

    function testBurnFromRevertsFromZeroAddressWithZeroAmount() public {
        vm.prank(spender);
        vm.expectRevert(ERC20Facet.ERC20Facet__BurnFromZeroAddress.selector);
        erc20Facet.burnFrom(address(0), 0);
    }

    function testFuzzTransferConservesSupply(address to, uint96 rawAmount) public {
        vm.assume(to != address(0));
        vm.assume(to != owner);

        uint256 amount = bound(uint256(rawAmount), 0, token.balanceOf(owner));
        uint256 supplyBefore = token.totalSupply();

        vm.prank(owner);
        assertTrue(token.transfer(to, amount));

        assertEq(token.totalSupply(), supplyBefore);
        assertEq(token.balanceOf(to), amount);
        assertEq(token.balanceOf(owner), INITIAL_SUPPLY - amount);
    }

    function testFuzzAllowanceSpendBounds(uint96 rawApproval, uint96 rawSpend) public {
        uint256 ownerBalance = token.balanceOf(owner);
        uint256 approval = bound(uint256(rawApproval), 0, ownerBalance);
        uint256 spend = bound(uint256(rawSpend), 0, ownerBalance);

        vm.prank(owner);
        assertTrue(token.approve(spender, approval));
        uint256 supplyBefore = token.totalSupply();

        vm.prank(spender);
        if (spend <= approval) {
            assertTrue(token.transferFrom(owner, bob, spend));
            assertEq(token.allowance(owner, spender), approval - spend);
            assertEq(token.balanceOf(bob), spend);
        } else {
            vm.expectRevert(abi.encodeWithSelector(ERC20Facet.ERC20Facet__InsufficientAllowance.selector, approval, spend));
            token.transferFrom(owner, bob, spend);
            assertEq(token.allowance(owner, spender), approval);
            assertEq(token.balanceOf(bob), 0);
        }

        assertEq(token.totalSupply(), supplyBefore);
    }

    function testFuzzAllowanceMonotonicity(uint96 rawApproval, uint96 rawSpend1, uint96 rawSpend2) public {
        uint256 ownerBalance = token.balanceOf(owner);
        uint256 approval = bound(uint256(rawApproval), 0, ownerBalance);
        uint256 spend1 = bound(uint256(rawSpend1), 0, ownerBalance);
        uint256 spend2 = bound(uint256(rawSpend2), 0, ownerBalance);

        vm.prank(owner);
        assertTrue(token.approve(spender, approval));

        if (spend1 > approval) {
            vm.prank(spender);
            vm.expectRevert(abi.encodeWithSelector(ERC20Facet.ERC20Facet__InsufficientAllowance.selector, approval, spend1));
            token.transferFrom(owner, bob, spend1);
            assertEq(token.allowance(owner, spender), approval);
            return;
        }

        vm.prank(spender);
        assertTrue(token.transferFrom(owner, bob, spend1));
        uint256 allowanceAfterFirst = approval - spend1;
        assertEq(token.allowance(owner, spender), allowanceAfterFirst);

        vm.prank(spender);
        if (spend2 <= allowanceAfterFirst) {
            assertTrue(token.transferFrom(owner, bob, spend2));
            assertEq(token.allowance(owner, spender), allowanceAfterFirst - spend2);
        } else {
            vm.expectRevert(
                abi.encodeWithSelector(ERC20Facet.ERC20Facet__InsufficientAllowance.selector, allowanceAfterFirst, spend2)
            );
            token.transferFrom(owner, bob, spend2);
            assertEq(token.allowance(owner, spender), allowanceAfterFirst);
        }
    }
}
