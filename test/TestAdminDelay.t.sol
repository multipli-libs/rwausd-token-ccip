// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";

import {RwaUsdBaseTest} from "./BaseTest.t.sol";

contract TestAdminDelay is RwaUsdBaseTest {
    function test_AdminDelay_ChangeScheduledCorrectly() public {
        uint48 newDelay = 2 hours;

        vm.prank(s_admin);
        s_rwausd.changeDefaultAdminDelay(newDelay);

        (uint48 pendingDelay, uint48 schedule) = s_rwausd.pendingDefaultAdminDelay();
        assertEq(pendingDelay, newDelay);
        assertGt(schedule, block.timestamp);
    }

    function test_AdminDelay_RevertWhen_ChangeCalledByNonAdmin() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, s_alice, s_rwausd.DEFAULT_ADMIN_ROLE()
            )
        );

        vm.prank(s_alice);
        s_rwausd.changeDefaultAdminDelay(2 hours);
    }

    function test_AdminDelay_NewDelayTakesEffectAfterSchedule() public {
        uint48 newDelay = 2 hours;

        vm.prank(s_admin);
        s_rwausd.changeDefaultAdminDelay(newDelay);

        (, uint48 schedule) = s_rwausd.pendingDefaultAdminDelay();
        vm.warp(schedule + 1);

        vm.prank(s_admin);
        s_rwausd.beginDefaultAdminTransfer(s_alice);

        assertEq(s_rwausd.defaultAdminDelay(), newDelay);
    }

    function test_AdminDelay_RollbackRestoresPreviousDelay() public {
        uint48 originalDelay = s_rwausd.defaultAdminDelay();

        vm.prank(s_admin);
        s_rwausd.changeDefaultAdminDelay(2 hours);

        vm.prank(s_admin);
        s_rwausd.rollbackDefaultAdminDelay();

        assertEq(s_rwausd.defaultAdminDelay(), originalDelay);
    }

    function test_AdminDelay_RevertWhen_RollbackCalledByNonAdmin() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, s_alice, s_rwausd.DEFAULT_ADMIN_ROLE()
            )
        );

        vm.prank(s_alice);
        s_rwausd.rollbackDefaultAdminDelay();
    }
}
