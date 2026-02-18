// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Test} from "forge-std/Test.sol";
import {ERC20Facet} from "src/facets/ERC20Facet.sol";
import {IDiamondCut} from "src/interfaces/IDiamondCut.sol";
import {MockFacetAdd} from "test/mocks/MockUpgradeFacets.sol";

contract Handler is Test {
    IERC20 internal immutable i_token;
    ERC20Facet internal immutable i_erc20Facet;
    IDiamondCut internal immutable i_diamondCut;
    address internal immutable i_owner;
    address internal immutable i_mockAddFacet;

    bool internal s_mockSelectorInstalled;
    address[] internal s_trackedHolders;
    mapping(address holder => bool isTracked) internal s_isTrackedHolder;
    address[] internal s_actorPool;

    constructor(address diamond, address owner, address[] memory initialActors) {
        i_token = IERC20(diamond);
        i_erc20Facet = ERC20Facet(diamond);
        i_diamondCut = IDiamondCut(diamond);
        i_owner = owner;
        i_mockAddFacet = address(new MockFacetAdd());

        _trackHolder(owner);
        for (uint256 i; i < initialActors.length; i++) {
            address actor = initialActors[i];
            if (actor != address(0)) {
                s_actorPool.push(actor);
                _trackHolder(actor);
            }
        }
    }

    function transfer(uint256 fromSeed, uint256 toSeed, uint256 amountSeed) external {
        address from = _pickTracked(fromSeed);
        address to = _pickNonZero(toSeed);
        uint256 balance = i_token.balanceOf(from);
        uint256 amount = bound(amountSeed, 0, balance);

        vm.prank(from);
        i_token.transfer(to, amount);
        _trackHolder(to);
    }

    function approve(uint256 ownerSeed, uint256 spenderSeed, uint256 amountSeed) external {
        address tokenOwner = _pickTracked(ownerSeed);
        address spender = _pickNonZero(spenderSeed);
        uint256 amount = bound(amountSeed, 0, type(uint128).max);

        vm.prank(tokenOwner);
        i_token.approve(spender, amount);
    }

    function transferFrom(uint256 spenderSeed, uint256 fromSeed, uint256 toSeed, uint256 amountSeed) external {
        address spender = _pickFromPool(spenderSeed);
        address from = _pickTracked(fromSeed);
        address to = _pickNonZero(toSeed);

        uint256 allowance = i_token.allowance(from, spender);
        uint256 balance = i_token.balanceOf(from);
        uint256 maxAmount = allowance < balance ? allowance : balance;
        uint256 amount = bound(amountSeed, 0, maxAmount);

        vm.prank(spender);
        i_token.transferFrom(from, to, amount);
        _trackHolder(to);
    }

    function mint(uint256 toSeed, uint256 amountSeed) external {
        address to = _pickNonZero(toSeed);
        uint256 amount = bound(amountSeed, 0, 1e24);

        vm.prank(i_owner);
        i_erc20Facet.mint(to, amount);
        _trackHolder(to);
    }

    function burn(uint256 fromSeed, uint256 amountSeed) external {
        address from = _pickTracked(fromSeed);
        uint256 balance = i_token.balanceOf(from);
        uint256 amount = bound(amountSeed, 0, balance);

        vm.prank(from);
        i_erc20Facet.burn(amount);
    }

    function burnFrom(uint256 spenderSeed, uint256 fromSeed, uint256 amountSeed) external {
        address spender = _pickFromPool(spenderSeed);
        address from = _pickTracked(fromSeed);

        uint256 allowance = i_token.allowance(from, spender);
        uint256 balance = i_token.balanceOf(from);
        uint256 maxAmount = allowance < balance ? allowance : balance;
        uint256 amount = bound(amountSeed, 0, maxAmount);

        vm.prank(spender);
        i_erc20Facet.burnFrom(from, amount);
    }

    function cutAddMockSelector() external {
        if (s_mockSelectorInstalled) {
            return;
        }

        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = MockFacetAdd.addedFunction.selector;
        IDiamondCut.FacetCut[] memory cut = new IDiamondCut.FacetCut[](1);
        cut[0] = IDiamondCut.FacetCut({
            facetAddress: i_mockAddFacet,
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: selectors
        });

        vm.prank(i_owner);
        i_diamondCut.diamondCut(cut, address(0), "");
        s_mockSelectorInstalled = true;
    }

    function cutRemoveMockSelector() external {
        if (!s_mockSelectorInstalled) {
            return;
        }

        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = MockFacetAdd.addedFunction.selector;
        IDiamondCut.FacetCut[] memory cut = new IDiamondCut.FacetCut[](1);
        cut[0] = IDiamondCut.FacetCut({
            facetAddress: address(0),
            action: IDiamondCut.FacetCutAction.Remove,
            functionSelectors: selectors
        });

        vm.prank(i_owner);
        i_diamondCut.diamondCut(cut, address(0), "");
        s_mockSelectorInstalled = false;
    }

    function trackedHoldersLength() external view returns (uint256) {
        return s_trackedHolders.length;
    }

    function trackedHolderAt(uint256 index) external view returns (address) {
        return s_trackedHolders[index];
    }

    function _pickTracked(uint256 seed) internal view returns (address) {
        return s_trackedHolders[seed % s_trackedHolders.length];
    }

    function _pickFromPool(uint256 seed) internal view returns (address) {
        if (s_actorPool.length == 0) {
            return i_owner;
        }
        return s_actorPool[seed % s_actorPool.length];
    }

    function _pickNonZero(uint256 seed) internal view returns (address) {
        address fromPool = _pickFromPool(seed);
        if (fromPool != address(0)) {
            return fromPool;
        }

        address derived = address(uint160(uint256(keccak256(abi.encode(seed, block.number)))));
        if (derived == address(0)) {
            return address(1);
        }
        return derived;
    }

    function _trackHolder(address holder) internal {
        if (holder == address(0) || s_isTrackedHolder[holder]) {
            return;
        }
        s_isTrackedHolder[holder] = true;
        s_trackedHolders.push(holder);
    }
}
