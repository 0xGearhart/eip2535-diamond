// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

contract MockInitSuccess {
    bytes32 internal constant POSITION = keccak256("diamond.test.init.success");

    struct Layout {
        uint256 value;
    }

    function initSetValue(uint256 newValue) external {
        Layout storage l;
        bytes32 position = POSITION;
        assembly {
            l.slot := position
        }
        l.value = newValue;
    }
}

contract MockInitReverter {
    error MockInitReverted();

    function initRevert() external pure {
        revert MockInitReverted();
    }
}
