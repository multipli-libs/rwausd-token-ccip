// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {rwaUSD} from "src/token/RWAUSD.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";

import {RwaUsdBaseTest} from "./BaseTest.t.sol";

contract TestUnfreeze is RwaUsdBaseTest {
    function test_Unfreeze() public {
        vm.prank(s_freezer);
        s_rwausd.freeze(s_alice);

        vm.expectEmit();
        emit rwaUSD.AccountUnfrozen(s_alice);

        vm.prank(s_freezer);
        s_rwausd.unfreeze(s_alice);

        assertFalse(s_rwausd.isFrozen(s_alice));
    }

    function test_Unfreeze_OperationsResume() public {
        vm.startPrank(s_freezer);
        s_rwausd.freeze(s_alice);
        s_rwausd.unfreeze(s_alice);
        vm.stopPrank();

        vm.prank(s_minter);
        s_rwausd.mint(s_alice, AMOUNT);
        assertEq(s_rwausd.balanceOf(s_alice), AMOUNT);

        vm.prank(s_alice);
        s_rwausd.approve(s_bob, AMOUNT);
        assertEq(s_rwausd.allowance(s_alice, s_bob), AMOUNT);

        vm.prank(s_alice);
        s_rwausd.transfer(s_bob, AMOUNT);
        assertEq(s_rwausd.balanceOf(s_bob), AMOUNT);
    }

    function test_Unfreeze_RevertWhen_CallerDoesNotHaveFreezerRole() public {
        vm.prank(s_freezer);
        s_rwausd.freeze(s_alice);

        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, s_bob, s_rwausd.FREEZER_ROLE()
            )
        );

        vm.prank(s_bob);
        s_rwausd.unfreeze(s_alice);
    }

    function test_Unfreeze_RevertWhen_AccountIsNotFrozen() public {
        assertFalse(s_rwausd.isFrozen(s_alice));

        vm.expectRevert(abi.encodeWithSelector(rwaUSD.RwaUsd__AccountNotFrozen.selector, s_alice));

        vm.prank(s_freezer);
        s_rwausd.unfreeze(s_alice);
    }
}
