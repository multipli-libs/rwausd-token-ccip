// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {rwaUSD} from "src/token/RWAUSD.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";

import {RwaUsdBaseTest} from "./BaseTest.t.sol";

contract TestRoles is RwaUsdBaseTest {
    function test_GrantMintAndBurnRoles() public {
        assertFalse(s_rwausd.hasRole(s_rwausd.MINTER_ROLE(), s_alice));
        assertFalse(s_rwausd.hasRole(s_rwausd.BURNER_ROLE(), s_alice));

        vm.expectEmit();
        emit IAccessControl.RoleGranted(s_rwausd.MINTER_ROLE(), s_alice, s_admin);
        vm.expectEmit();
        emit IAccessControl.RoleGranted(s_rwausd.BURNER_ROLE(), s_alice, s_admin);

        vm.prank(s_admin);
        s_rwausd.grantMintAndBurnRoles(s_alice);

        assertTrue(s_rwausd.hasRole(s_rwausd.MINTER_ROLE(), s_alice));
        assertTrue(s_rwausd.hasRole(s_rwausd.BURNER_ROLE(), s_alice));
    }

    function test_GetCCIPAdmin() public view {
        assertEq(s_rwausd.getCCIPAdmin(), s_admin);
    }

    function test_SetCCIPAdmin_EmitsEvent() public {
        vm.expectEmit();
        emit rwaUSD.CCIPAdminTransferred(s_admin, s_alice);

        vm.prank(s_admin);
        s_rwausd.setCCIPAdmin(s_alice);
    }

    function test_SetCCIPAdmin() public {
        vm.expectEmit();
        emit rwaUSD.CCIPAdminTransferred(s_admin, s_alice);

        vm.prank(s_admin);
        s_rwausd.setCCIPAdmin(s_alice);

        assertEq(s_rwausd.getCCIPAdmin(), s_alice);
    }

    function test_SetCCIPAdmin_RevertWhen_CallerDoesNotHaveDefaultAdminRole() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, s_alice, s_rwausd.DEFAULT_ADMIN_ROLE()
            )
        );

        vm.prank(s_alice);
        s_rwausd.setCCIPAdmin(s_alice);
    }

    function test_SetCCIPAdmin_CanBeSetToZeroAddress() public {
        vm.prank(s_admin);
        s_rwausd.setCCIPAdmin(address(0));

        assertEq(s_rwausd.getCCIPAdmin(), address(0));
    }
}
