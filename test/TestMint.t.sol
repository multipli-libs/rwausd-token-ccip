// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {rwaUSD} from "src/token/RWAUSD.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";

import {RwaUsdBaseTest} from "./BaseTest.t.sol";

contract TestMint is RwaUsdBaseTest {
    function test_Mint_Success() public {
        uint256 balanceBefore = s_rwausd.balanceOf(s_alice);

        vm.expectEmit();
        emit IERC20.Transfer(address(0), s_alice, AMOUNT);

        vm.prank(s_minter);
        s_rwausd.mint(s_alice, AMOUNT);

        assertEq(s_rwausd.balanceOf(s_alice), balanceBefore + AMOUNT);
        assertEq(s_rwausd.totalSupply(), AMOUNT);
    }

    function test_Mint_RevertWhen_AmountExceedsMaxSupply() public {
        address implementation = address(new rwaUSD());
        ERC1967Proxy proxy = new ERC1967Proxy(
            implementation,
            abi.encodeCall(rwaUSD.initialize, ("Real World Asset USD", "rwaUSD", 18, 1000e18, 0, s_admin, s_admin))
        );
        rwaUSD cappedToken = rwaUSD(address(proxy));

        vm.startPrank(s_admin);
        cappedToken.grantRole(cappedToken.MINTER_ROLE(), s_minter);
        vm.stopPrank();

        uint256 amountToMint = cappedToken.maxSupply() + AMOUNT;

        vm.expectRevert(abi.encodeWithSelector(rwaUSD.RwaUsd__MaxSupplyExceeded.selector, amountToMint));

        vm.prank(s_minter);
        cappedToken.mint(s_alice, amountToMint);
    }

    function test_Mint_RevertWhen_CallerDoesNotHaveMinterRole() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, s_alice, s_rwausd.MINTER_ROLE()
            )
        );

        vm.prank(s_alice);
        s_rwausd.mint(s_alice, AMOUNT);
    }

    function test_Mint_RevertWhen_RecipientIsImplementationItself() public {
        vm.expectRevert(abi.encodeWithSelector(rwaUSD.RwaUsd__InvalidRecipient.selector, address(s_rwausd)));

        vm.prank(s_minter);
        s_rwausd.mint(address(s_rwausd), AMOUNT);
    }

    function test_Mint_RevertWhen_ImplementationIsPaused() public {
        vm.prank(s_pauser);
        s_rwausd.pause();

        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);

        vm.prank(s_minter);
        s_rwausd.mint(s_alice, AMOUNT);
    }
}
