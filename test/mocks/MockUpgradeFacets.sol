// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

library MockUpgradeStorage {
    bytes32 internal constant POSITION = keccak256("diamond.test.upgrade.storage");

    struct Layout {
        uint256 value;
    }

    function layout() internal pure returns (Layout storage l) {
        bytes32 position = POSITION;
        assembly {
            l.slot := position
        }
    }
}

contract MockFacetAdd {
    function addedFunction() external pure returns (uint256) {
        return 111;
    }
}

contract MockFacetReplaceV1 {
    function replacedFunction() external pure returns (uint256) {
        return 1;
    }

    function setSharedValue(uint256 newValue) external {
        MockUpgradeStorage.layout().value = newValue;
    }

    function getSharedValue() external view returns (uint256) {
        return MockUpgradeStorage.layout().value;
    }
}

contract MockFacetReplaceV2 {
    function replacedFunction() external pure returns (uint256) {
        return 2;
    }

    function getSharedValue() external view returns (uint256) {
        return MockUpgradeStorage.layout().value + 1;
    }
}
