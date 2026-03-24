// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {rwaUSD} from "src/token/RWAUSD.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";

import {RwaUsdBaseTest} from "./BaseTest.t.sol";

contract TestTransfer is RwaUsdBaseTest {
    function test_Transfer_Success() public {
        vm.prank(s_minter);
        s_rwausd.mint(s_alice, AMOUNT);

        vm.expectEmit();
        emit IERC20.Transfer(s_alice, s_bob, AMOUNT);

        vm.prank(s_alice);
        s_rwausd.transfer(s_bob, AMOUNT);

        assertEq(s_rwausd.balanceOf(s_alice), 0);
        assertEq(s_rwausd.balanceOf(s_bob), AMOUNT);
    }

    function test_TransferFrom_Success() public {
        vm.prank(s_minter);
        s_rwausd.mint(s_alice, AMOUNT);

        vm.prank(s_alice);
        s_rwausd.approve(s_bob, AMOUNT);

        vm.expectEmit();
        emit IERC20.Transfer(s_alice, s_bob, AMOUNT);

        vm.prank(s_bob);
        s_rwausd.transferFrom(s_alice, s_bob, AMOUNT);

        assertEq(s_rwausd.balanceOf(s_alice), 0);
        assertEq(s_rwausd.balanceOf(s_bob), AMOUNT);
    }

    function test_Transfer_RevertWhen_RecipientIsContractItself() public {
        vm.prank(s_minter);
        s_rwausd.mint(s_alice, AMOUNT);

        vm.expectRevert(abi.encodeWithSelector(rwaUSD.RwaUsd__InvalidRecipient.selector, address(s_rwausd)));

        vm.prank(s_alice);
        s_rwausd.transfer(address(s_rwausd), AMOUNT);
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
}
