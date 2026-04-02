// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import {
    AccessControlDefaultAdminRulesUpgradeable
} from "@openzeppelin/contracts-upgradeable/access/extensions/AccessControlDefaultAdminRulesUpgradeable.sol";

contract AcceptDefaultAdminTransfer is Script {
    function run() external {
        address target = 0x8Fcd23142047A3073ed332a0Ed07d1e8D2BD5177;

        bytes memory data =
            abi.encodeWithSelector(AccessControlDefaultAdminRulesUpgradeable.acceptDefaultAdminTransfer.selector);

        console.log("Target:", target);
        console.log("Calldata:");
        console.logBytes(data);
    }
}
