// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {rwaUSD} from "src/token/RWAUSD.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";

import {RwaUsdBaseTest} from "./BaseTest.t.sol";

contract TestPausing is RwaUsdBaseTest {
    function test_Pause() public {
        vm.expectEmit();
        emit PausableUpgradeable.Paused(s_pauser);

        vm.prank(s_pauser);
        s_rwausd.pause();

        assertTrue(s_rwausd.paused());
    }

    function test_Unpause() public {
        vm.prank(s_pauser);
        s_rwausd.pause();

        vm.expectEmit();
        emit PausableUpgradeable.Unpaused(s_admin);

        vm.prank(s_admin);
        s_rwausd.unpause();

        assertFalse(s_rwausd.paused());

        vm.expectEmit();
        emit IERC20.Transfer(address(0), s_alice, AMOUNT);

        vm.prank(s_minter);
        s_rwausd.mint(s_alice, AMOUNT);

        vm.prank(s_alice);
        s_rwausd.approve(s_bob, AMOUNT);
        assertEq(s_rwausd.allowance(s_alice, s_bob), AMOUNT);
    }

    function test_Pause_RevertWhen_CallerDoesNotHavePauserRole() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, s_alice, s_rwausd.PAUSER_ROLE()
            )
        );

        vm.prank(s_alice);
        s_rwausd.pause();
    }

    function test_Unpause_RevertWhen_CallerDoesNotHaveDefaultAdminRole() public {
        vm.prank(s_pauser);
        s_rwausd.pause();

        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, s_alice, s_rwausd.DEFAULT_ADMIN_ROLE()
            )
        );

        vm.prank(s_alice);
        s_rwausd.unpause();
    }

    function test_Mint_RevertWhen_ImplementationIsPaused() public {
        vm.prank(s_pauser);
        s_rwausd.pause();

        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);

        vm.prank(s_minter);
        s_rwausd.mint(s_alice, AMOUNT);
    }

    function test_Transfer_RevertWhen_ImplementationIsPaused() public {
        vm.prank(s_minter);
        s_rwausd.mint(s_alice, AMOUNT);

        vm.prank(s_pauser);
        s_rwausd.pause();

        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);

        vm.prank(s_alice);
        s_rwausd.transfer(s_bob, AMOUNT);
    }

    function test_Burn_RevertWhen_ImplementationIsPaused() public {
        vm.prank(s_pauser);
        s_rwausd.pause();

        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);

        vm.prank(s_burner);
        s_rwausd.burn(0);
    }

    function test_BurnFrom_RevertWhen_ImplementationIsPaused() public {
        vm.prank(s_pauser);
        s_rwausd.pause();

        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);

        vm.prank(s_burner);
        s_rwausd.burnFrom(s_alice, 0);
    }

    function test_BurnFrom_alias_RevertWhen_ImplementationIsPaused() public {
        vm.prank(s_pauser);
        s_rwausd.pause();

        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);

        vm.prank(s_burner);
        s_rwausd.burn(s_alice, 0);
    }

    function test_Approve_RevertWhen_ImplementationIsPaused() public {
        vm.prank(s_pauser);
        s_rwausd.pause();

        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);

        vm.prank(s_alice);
        s_rwausd.approve(s_bob, AMOUNT);
    }
}
