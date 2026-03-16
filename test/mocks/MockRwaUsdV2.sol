// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {RwaUsd} from "src/token/RwaUsd.sol";

/// @custom:oz-upgrades-from RwaUsd
contract MockRwaUsdV2 is RwaUsd {
    //new methods
    uint256 public newVariable;

    function newMethod() public pure returns (string memory) {
        return "new method";
    }

    function setNewVariable(uint256 value) public {
        newVariable = value;
    }
}
