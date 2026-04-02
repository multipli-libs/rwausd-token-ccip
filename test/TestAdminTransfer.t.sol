// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {rwaUSD} from "src/token/RWAUSD.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {
    IAccessControlDefaultAdminRules
} from "@openzeppelin/contracts/access/extensions/IAccessControlDefaultAdminRules.sol";

import {RwaUsdBaseTest} from "./BaseTest.t.sol";

contract TestAdminTransfer is RwaUsdBaseTest {
    function _completeAdminTransfer(address currentAdmin, address newAdmin) internal {
        vm.prank(currentAdmin);
        s_rwausd.beginDefaultAdminTransfer(newAdmin);

        (, uint48 schedule) = s_rwausd.pendingDefaultAdmin();
        vm.warp(schedule + 1);

        vm.prank(newAdmin);
        s_rwausd.acceptDefaultAdminTransfer();
    }

    function test_AdminTransfer_RevertWhen_DefaultAdminRoleGrantedDirectly() public {
        vm.startPrank(s_admin);
        (bool success, bytes memory returnData) = address(s_rwausd)
            .call(abi.encodeWithSelector(s_rwausd.grantRole.selector, s_rwausd.DEFAULT_ADMIN_ROLE(), s_alice));
        vm.stopPrank();

        assertFalse(success, "grantRole(DEFAULT_ADMIN_ROLE) should have reverted");
        assertEq(
            bytes4(returnData),
            IAccessControlDefaultAdminRules.AccessControlEnforcedDefaultAdminRules.selector,
            "unexpected revert selector"
        );
    }

    function test_AdminTransfer_RevertWhen_DefaultAdminRoleRevokedDirectly() public {
        vm.startPrank(s_admin);
        (bool success, bytes memory returnData) = address(s_rwausd)
            .call(abi.encodeWithSelector(s_rwausd.revokeRole.selector, s_rwausd.DEFAULT_ADMIN_ROLE(), s_admin));
        vm.stopPrank();

        assertFalse(success, "revokeRole(DEFAULT_ADMIN_ROLE) should have reverted");
        assertEq(
            bytes4(returnData),
            IAccessControlDefaultAdminRules.AccessControlEnforcedDefaultAdminRules.selector,
            "unexpected revert selector"
        );
    }

    function test_AdminTransfer_BeginTransferSetsPendingAdmin() public {
        vm.prank(s_admin);
        s_rwausd.beginDefaultAdminTransfer(s_alice);

        (address pendingAdmin, uint48 schedule) = s_rwausd.pendingDefaultAdmin();
        assertEq(pendingAdmin, s_alice);
        assertGt(schedule, block.timestamp);
    }

    function test_AdminTransfer_RevertWhen_BeginTransferCalledByNonAdmin() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, s_alice, s_rwausd.DEFAULT_ADMIN_ROLE()
            )
        );

        vm.prank(s_alice);
        s_rwausd.beginDefaultAdminTransfer(s_bob);
    }

    function test_AdminTransfer_RevertWhen_AcceptedBeforeDelayPasses() public {
        vm.prank(s_admin);
        s_rwausd.beginDefaultAdminTransfer(s_alice);

        (, uint48 schedule) = s_rwausd.pendingDefaultAdmin();
        vm.warp(schedule - 1);

        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControlDefaultAdminRules.AccessControlEnforcedDefaultAdminDelay.selector, schedule
            )
        );

        vm.prank(s_alice);
        s_rwausd.acceptDefaultAdminTransfer();
    }

    function test_AdminTransfer_SuccessAfterDelayPasses() public {
        _completeAdminTransfer(s_admin, s_alice);

        assertEq(s_rwausd.defaultAdmin(), s_alice);
        assertFalse(s_rwausd.hasRole(s_rwausd.DEFAULT_ADMIN_ROLE(), s_admin));
        assertTrue(s_rwausd.hasRole(s_rwausd.DEFAULT_ADMIN_ROLE(), s_alice));
    }

    function test_AdminTransfer_RevertWhen_AcceptedByWrongAccount() public {
        vm.prank(s_admin);
        s_rwausd.beginDefaultAdminTransfer(s_alice);

        (, uint48 schedule) = s_rwausd.pendingDefaultAdmin();
        vm.warp(schedule + 1);

        vm.expectRevert(
            abi.encodeWithSelector(IAccessControlDefaultAdminRules.AccessControlInvalidDefaultAdmin.selector, s_bob)
        );

        vm.prank(s_bob);
        s_rwausd.acceptDefaultAdminTransfer();
    }

    function test_AdminTransfer_CancelClearsPendingAdmin() public {
        vm.prank(s_admin);
        s_rwausd.beginDefaultAdminTransfer(s_alice);

        vm.prank(s_admin);
        s_rwausd.cancelDefaultAdminTransfer();

        (address pendingAdmin, uint48 schedule) = s_rwausd.pendingDefaultAdmin();
        assertEq(pendingAdmin, address(0));
        assertEq(schedule, 0);
    }

    function test_AdminTransfer_RevertWhen_CancelCalledByNonAdmin() public {
        vm.prank(s_admin);
        s_rwausd.beginDefaultAdminTransfer(s_alice);

        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, s_alice, s_rwausd.DEFAULT_ADMIN_ROLE()
            )
        );

        vm.prank(s_alice);
        s_rwausd.cancelDefaultAdminTransfer();
    }

    function test_AdminTransfer_CancelledTransferCannotBeAccepted() public {
        vm.prank(s_admin);
        s_rwausd.beginDefaultAdminTransfer(s_alice);

        (, uint48 schedule) = s_rwausd.pendingDefaultAdmin();

        vm.prank(s_admin);
        s_rwausd.cancelDefaultAdminTransfer();

        vm.warp(schedule + 1);

        vm.expectRevert(
            abi.encodeWithSelector(IAccessControlDefaultAdminRules.AccessControlInvalidDefaultAdmin.selector, s_alice)
        );

        vm.prank(s_alice);
        s_rwausd.acceptDefaultAdminTransfer();
    }

    function test_AdminTransfer_OldAdminLosesRoleAfterTransfer() public {
        _completeAdminTransfer(s_admin, s_alice);

        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, s_admin, s_rwausd.DEFAULT_ADMIN_ROLE()
            )
        );

        vm.prank(s_admin);
        s_rwausd.setCCIPAdmin(s_bob);
    }

    function test_AdminTransfer_NewAdminCanGrantRoles() public {
        _completeAdminTransfer(s_admin, s_alice);

        assertEq(s_rwausd.defaultAdmin(), s_alice);

        vm.startPrank(s_alice);
        s_rwausd.grantRole(s_rwausd.MINTER_ROLE(), s_bob);
        vm.stopPrank();

        assertTrue(s_rwausd.hasRole(s_rwausd.MINTER_ROLE(), s_bob));
    }

    function test_AdminTransfer_NewAdminCanCallAdminGatedFunctions() public {
        _completeAdminTransfer(s_admin, s_alice);

        vm.prank(s_alice);
        s_rwausd.setCCIPAdmin(s_bob);

        assertEq(s_rwausd.getCCIPAdmin(), s_bob);
    }

    function test_AdminTransfer_PendingAdminUpdatedOnSecondBeginTransfer() public {
        vm.prank(s_admin);
        s_rwausd.beginDefaultAdminTransfer(s_alice);

        vm.prank(s_admin);
        s_rwausd.beginDefaultAdminTransfer(s_bob);

        (address pendingAdmin,) = s_rwausd.pendingDefaultAdmin();
        assertEq(pendingAdmin, s_bob);
    }

    function test_AdminTransfer_DelayIsRespectedOnNewTransfer() public {
        _completeAdminTransfer(s_admin, s_alice);

        vm.prank(s_alice);
        s_rwausd.beginDefaultAdminTransfer(s_bob);

        (, uint48 schedule) = s_rwausd.pendingDefaultAdmin();
        vm.warp(schedule - 1);

        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControlDefaultAdminRules.AccessControlEnforcedDefaultAdminDelay.selector, schedule
            )
        );

        vm.prank(s_bob);
        s_rwausd.acceptDefaultAdminTransfer();
    }
}
