// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {rwaUSD} from "src/token/RWAUSD.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";

import {RwaUsdBaseTest} from "./BaseTest.t.sol";

contract TestApprove is RwaUsdBaseTest {
    function test_Approve_Success() public {
        vm.prank(s_minter);
        s_rwausd.mint(s_alice, AMOUNT);

        vm.expectEmit();
        emit IERC20.Approval(s_alice, s_bob, AMOUNT);

        vm.prank(s_alice);
        s_rwausd.approve(s_bob, AMOUNT);

        assertEq(s_rwausd.allowance(s_alice, s_bob), AMOUNT);
    }

    function test_Approve_OverwritesExistingAllowance() public {
        vm.prank(s_minter);
        s_rwausd.mint(s_alice, AMOUNT);

        vm.prank(s_alice);
        s_rwausd.approve(s_bob, AMOUNT);

        uint256 newAllowance = AMOUNT * 2;

        vm.expectEmit();
        emit IERC20.Approval(s_alice, s_bob, newAllowance);

        vm.prank(s_alice);
        s_rwausd.approve(s_bob, newAllowance);

        assertEq(s_rwausd.allowance(s_alice, s_bob), newAllowance);
    }

    function test_Approve_ToZeroRevokesAllowance() public {
        vm.prank(s_minter);
        s_rwausd.mint(s_alice, AMOUNT);

        vm.prank(s_alice);
        s_rwausd.approve(s_bob, AMOUNT);

        vm.expectEmit();
        emit IERC20.Approval(s_alice, s_bob, 0);

        vm.prank(s_alice);
        s_rwausd.approve(s_bob, 0);

        assertEq(s_rwausd.allowance(s_alice, s_bob), 0);
    }

    function test_Approve_RevertWhen_SpenderIsContractItself() public {
        vm.expectRevert(abi.encodeWithSelector(rwaUSD.RwaUsd__InvalidRecipient.selector, address(s_rwausd)));

        vm.prank(s_alice);
        s_rwausd.approve(address(s_rwausd), AMOUNT);
    }

    function test_Approve_RevertWhen_ImplementationIsPaused() public {
        vm.prank(s_pauser);
        s_rwausd.pause();

        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);

        vm.prank(s_alice);
        s_rwausd.approve(s_bob, AMOUNT);
    }
}
