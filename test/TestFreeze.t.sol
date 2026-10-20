// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {rwaUSD} from "src/token/RWAUSD.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";

import {RwaUsdBaseTest} from "./BaseTest.t.sol";

contract TestFreeze is RwaUsdBaseTest {
    function test_Freeze() public {
        vm.expectEmit();
        emit rwaUSD.AccountFrozen(s_alice);

        vm.prank(s_freezer);
        s_rwausd.freeze(s_alice);

        assertTrue(s_rwausd.isFrozen(s_alice));
    }

    function test_Freeze_RevertWhen_CallerDoesNotHaveFreezerRole() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, s_alice, s_rwausd.FREEZER_ROLE()
            )
        );

        vm.prank(s_alice);
        s_rwausd.freeze(s_bob);
    }

    function test_Freeze_RevertWhen_AccountIsAddressZero() public {
        vm.expectRevert(abi.encodeWithSelector(rwaUSD.RwaUsd__InvalidAddress.selector, address(0)));

        vm.prank(s_freezer);
        s_rwausd.freeze(address(0));
    }

    function test_Freeze_RevertWhen_AccountIsTheTokenItself() public {
        vm.expectRevert(abi.encodeWithSelector(rwaUSD.RwaUsd__InvalidAddress.selector, address(s_rwausd)));

        vm.prank(s_freezer);
        s_rwausd.freeze(address(s_rwausd));
    }

    function test_Freeze_RevertWhen_AccountIsAlreadyFrozen() public {
        vm.startPrank(s_freezer);
        s_rwausd.freeze(s_alice);

        vm.expectRevert(abi.encodeWithSelector(rwaUSD.RwaUsd__AccountFrozen.selector, s_alice));
        s_rwausd.freeze(s_alice);
        vm.stopPrank();
    }

    function test_Mint_RevertWhen_RecipientIsFrozen() public {
        vm.prank(s_freezer);
        s_rwausd.freeze(s_alice);

        vm.expectRevert(abi.encodeWithSelector(rwaUSD.RwaUsd__AccountFrozen.selector, s_alice));

        vm.prank(s_minter);
        s_rwausd.mint(s_alice, AMOUNT);
    }

    function test_Mint_RevertWhen_MinterIsFrozen() public {
        vm.prank(s_freezer);
        s_rwausd.freeze(s_minter);

        vm.expectRevert(abi.encodeWithSelector(rwaUSD.RwaUsd__AccountFrozen.selector, s_minter));

        vm.prank(s_minter);
        s_rwausd.mint(s_alice, AMOUNT);
    }

    function test_BurnFrom_RevertWhen_HolderIsFrozen() public {
        vm.prank(s_minter);
        s_rwausd.mint(s_alice, AMOUNT);

        vm.prank(s_alice);
        s_rwausd.approve(s_burner, AMOUNT);

        vm.prank(s_freezer);
        s_rwausd.freeze(s_alice);

        vm.expectRevert(abi.encodeWithSelector(rwaUSD.RwaUsd__AccountFrozen.selector, s_alice));

        vm.prank(s_burner);
        s_rwausd.burnFrom(s_alice, AMOUNT);
    }

    function test_BurnFrom_RevertWhen_BurnerIsFrozen() public {
        vm.prank(s_minter);
        s_rwausd.mint(s_alice, AMOUNT);

        vm.prank(s_alice);
        s_rwausd.approve(s_burner, AMOUNT);

        vm.prank(s_freezer);
        s_rwausd.freeze(s_burner);

        vm.expectRevert(abi.encodeWithSelector(rwaUSD.RwaUsd__AccountFrozen.selector, s_burner));

        vm.prank(s_burner);
        s_rwausd.burnFrom(s_alice, AMOUNT);
    }

    function test_Transfer_RevertWhen_SenderIsFrozen() public {
        vm.prank(s_minter);
        s_rwausd.mint(s_alice, AMOUNT);

        vm.prank(s_freezer);
        s_rwausd.freeze(s_alice);

        vm.expectRevert(abi.encodeWithSelector(rwaUSD.RwaUsd__AccountFrozen.selector, s_alice));

        vm.prank(s_alice);
        s_rwausd.transfer(s_bob, AMOUNT);
    }

    function test_Transfer_RevertWhen_RecipientIsFrozen() public {
        vm.prank(s_minter);
        s_rwausd.mint(s_alice, AMOUNT);

        vm.prank(s_freezer);
        s_rwausd.freeze(s_bob);

        vm.expectRevert(abi.encodeWithSelector(rwaUSD.RwaUsd__AccountFrozen.selector, s_bob));

        vm.prank(s_alice);
        s_rwausd.transfer(s_bob, AMOUNT);
    }

    function test_TransferFrom_RevertWhen_SpenderIsFrozen() public {
        vm.prank(s_minter);
        s_rwausd.mint(s_alice, AMOUNT);

        vm.prank(s_alice);
        s_rwausd.approve(s_bob, AMOUNT);

        vm.prank(s_freezer);
        s_rwausd.freeze(s_bob);

        vm.expectRevert(abi.encodeWithSelector(rwaUSD.RwaUsd__AccountFrozen.selector, s_bob));

        vm.prank(s_bob);
        s_rwausd.transferFrom(s_alice, s_bob, AMOUNT);
    }

    function test_Approve_RevertWhen_OwnerIsFrozen() public {
        vm.prank(s_freezer);
        s_rwausd.freeze(s_alice);

        vm.expectRevert(abi.encodeWithSelector(rwaUSD.RwaUsd__AccountFrozen.selector, s_alice));

        vm.prank(s_alice);
        s_rwausd.approve(s_bob, AMOUNT);
    }

    function test_Approve_RevertWhen_SpenderIsFrozen() public {
        vm.prank(s_freezer);
        s_rwausd.freeze(s_bob);

        vm.expectRevert(abi.encodeWithSelector(rwaUSD.RwaUsd__AccountFrozen.selector, s_bob));

        vm.prank(s_alice);
        s_rwausd.approve(s_bob, AMOUNT);
    }

    function test_IsFrozen_DefaultsToFalse() public view {
        assertFalse(s_rwausd.isFrozen(s_alice));
        assertFalse(s_rwausd.isFrozen(address(0)));
    }

    function test_Freeze_DoesNotAffectOtherAccounts() public {
        vm.prank(s_minter);
        s_rwausd.mint(s_alice, AMOUNT);

        vm.prank(s_freezer);
        s_rwausd.freeze(s_bob);

        address carol = makeAddr("carol");

        vm.prank(s_alice);
        s_rwausd.transfer(carol, AMOUNT);

        assertEq(s_rwausd.balanceOf(carol), AMOUNT);
    }
}
