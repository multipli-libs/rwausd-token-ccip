// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {rwaUSD} from "src/token/RWAUSD.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";

import {RwaUsdBaseTest} from "./BaseTest.t.sol";

contract TestBurn is RwaUsdBaseTest {
    function test_Burn_Success() public {
        vm.prank(s_minter);
        s_rwausd.mint(s_burner, AMOUNT);

        uint256 amountToBurn = AMOUNT / 2;
        uint256 balanceBefore = s_rwausd.balanceOf(s_burner);
        uint256 totalSupplyBefore = s_rwausd.totalSupply();

        vm.expectEmit();
        emit IERC20.Transfer(s_burner, address(0), amountToBurn);

        vm.prank(s_burner);
        s_rwausd.burn(amountToBurn);

        assertEq(s_rwausd.balanceOf(s_burner), balanceBefore - amountToBurn);
        assertEq(s_rwausd.totalSupply(), totalSupplyBefore - amountToBurn);
    }

    function test_Burn_RevertWhen_CallerDoesNotHaveBurnerRole() public {
        vm.prank(s_minter);
        s_rwausd.mint(s_alice, AMOUNT);

        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, s_alice, s_rwausd.BURNER_ROLE()
            )
        );

        vm.prank(s_alice);
        s_rwausd.burn(AMOUNT);
    }

    function test_Burn_RevertWhen_ImplementationIsPaused() public {
        vm.prank(s_minter);
        s_rwausd.mint(s_burner, AMOUNT);

        vm.prank(s_pauser);
        s_rwausd.pause();

        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);

        vm.prank(s_burner);
        s_rwausd.burn(AMOUNT);
    }
}
