// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {rwaUSD} from "src/token/rwaUSD.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {
    IAccessControlDefaultAdminRules
} from "@openzeppelin/contracts/access/extensions/IAccessControlDefaultAdminRules.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";

contract RwaUsdBaseTest is Test {
    rwaUSD internal s_rwausd;

    address internal s_admin = makeAddr("admin");
    address internal s_minter = makeAddr("minter");
    address internal s_burner = makeAddr("burner");
    address internal s_pauser = makeAddr("pauser");
    address internal s_upgrader = makeAddr("upgrader");
    address internal s_alice = makeAddr("alice");
    address internal s_bob = makeAddr("bob");
    address internal s_deployer = makeAddr("deployer");

    uint256 internal constant AMOUNT = 100e18;
    uint48 internal constant ADMIN_DELAY = 1 hours;

    function setUp() public virtual {
        vm.startPrank(s_deployer);

        bytes memory data = abi.encodeCall(
            rwaUSD.initialize,
            (
                "Real World Asset USD",
                "rwaUSD",
                uint8(18),
                0, // maxSupply (unlimited)
                0, // preMint
                s_admin,
                s_admin // defaultUpgrader
            )
        );

        address proxy = Upgrades.deployUUPSProxy("rwaUSD.sol:rwaUSD", data);
        s_rwausd = rwaUSD(proxy);
        vm.stopPrank();

        vm.startPrank(s_admin);
        s_rwausd.grantRole(s_rwausd.MINTER_ROLE(), s_minter);
        s_rwausd.grantRole(s_rwausd.BURNER_ROLE(), s_burner);
        s_rwausd.grantRole(s_rwausd.PAUSER_ROLE(), s_pauser);
        vm.stopPrank();
    }
}
