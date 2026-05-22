// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {rwaUSD} from "src/token/RWAUSD.sol";

/// @custom:oz-upgrades-from src/token/RWAUSD.sol:rwaUSD
contract MockRwaUsdV2 is rwaUSD {
    //new methods
    uint256 public newVariable;

    function newMethod() public pure returns (string memory) {
        return "new method";
    }

    function setNewVariable(uint256 value) public {
        newVariable = value;
    }
}
