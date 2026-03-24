// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {rwaUSD} from "src/token/RWAUSD.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";

import {RwaUsdBaseTest} from "./BaseTest.t.sol";

contract TestBurnFromAlias is RwaUsdBaseTest {
    function test_BurnFrom_alias_Success() public {
        vm.prank(s_minter);
        s_rwausd.mint(s_alice, AMOUNT);

        uint256 balanceBefore = s_rwausd.balanceOf(s_alice);
        uint256 totalSupplyBefore = s_rwausd.totalSupply();
        uint256 amountToBurn = AMOUNT / 2;

        vm.prank(s_alice);
        s_rwausd.approve(s_burner, amountToBurn);

        vm.expectEmit();
        emit IERC20.Transfer(s_alice, address(0), amountToBurn);

        // burn(account, amount) is an alias for burnFrom(account, amount)
        vm.prank(s_burner);
        s_rwausd.burn(s_alice, amountToBurn);

        assertEq(s_rwausd.balanceOf(s_alice), balanceBefore - amountToBurn);
        assertEq(s_rwausd.totalSupply(), totalSupplyBefore - amountToBurn);
    }

    function test_BurnFrom_alias_RevertWhen_CallerDoesNotHaveBurnerRole() public {
        vm.prank(s_minter);
        s_rwausd.mint(s_alice, AMOUNT);

        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, s_bob, s_rwausd.BURNER_ROLE()
            )
        );

        vm.prank(s_bob);
        s_rwausd.burn(s_alice, AMOUNT);
    }

    function test_BurnFrom_alias_RevertWhen_ImplementationIsPaused() public {
        vm.prank(s_minter);
        s_rwausd.mint(s_alice, AMOUNT);

        vm.prank(s_alice);
        s_rwausd.approve(s_burner, AMOUNT);

        vm.prank(s_pauser);
        s_rwausd.pause();

        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);

        vm.prank(s_burner);
        s_rwausd.burn(s_alice, AMOUNT);
    }
}
