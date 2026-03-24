// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {rwaUSD} from "src/token/rwaUSD.sol";
import {MockRwaUsdV2} from "./mocks/MockRwaUsdV2.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {
    IAccessControlDefaultAdminRules
} from "@openzeppelin/contracts/access/extensions/IAccessControlDefaultAdminRules.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";

import {RwaUsdBaseTest} from "./BaseTest.t.sol";

contract TestUpgrade is RwaUsdBaseTest {
    /// @dev The ERC-7201 storage slot for RwaUsdStorage:
    ///      keccak256(abi.encode(uint256(keccak256("multipli.storage.rwaUSD")) - 1)) & ~bytes32(uint256(0xff))
    ///
    ///      Struct layout (ERC-7201):
    ///        slot+0  → address ccipAdmin (bits 0–159) + uint8 decimals (bits 160–167), packed
    ///        slot+1  → uint256 maxSupply
    bytes32 internal constant RWAUSD_STORAGE_LOCATION =
        0xc1a8840385e35995fb7aabd6059552ccaa64bb804485e90cb444ac534e5ef600;

    bytes32 internal constant SLOT_CCIP_DECIMALS = RWAUSD_STORAGE_LOCATION;
    bytes32 internal constant SLOT_MAX_SUPPLY = bytes32(uint256(RWAUSD_STORAGE_LOCATION) + 1);

    function _completeAdminTransfer(address currentAdmin, address newAdmin) internal {
        vm.prank(currentAdmin);
        s_rwausd.beginDefaultAdminTransfer(newAdmin);

        (, uint48 schedule) = s_rwausd.pendingDefaultAdmin();
        vm.warp(schedule + 1);

        vm.prank(newAdmin);
        s_rwausd.acceptDefaultAdminTransfer();
    }

    function _readNamespaceWindow(address proxy)
        internal
        view
        returns (bytes32 slotMinus1, bytes32 slot0, bytes32 slot1, bytes32 slot2)
    {
        slotMinus1 = vm.load(proxy, bytes32(uint256(RWAUSD_STORAGE_LOCATION) - 1));
        slot0 = vm.load(proxy, RWAUSD_STORAGE_LOCATION);
        slot1 = vm.load(proxy, bytes32(uint256(RWAUSD_STORAGE_LOCATION) + 1));
        slot2 = vm.load(proxy, bytes32(uint256(RWAUSD_STORAGE_LOCATION) + 2));
    }

    // ================================================================
    // │                        Upgrade                               │
    // ================================================================

    function test_Upgrade_Success() public {
        vm.startPrank(s_admin);
        Upgrades.upgradeProxy(address(s_rwausd), "MockRwaUsdV2.sol", "");
        vm.stopPrank();

        string memory response = MockRwaUsdV2(address(s_rwausd)).newMethod();
        assertEq(response, "new method");
    }

    function test_Upgrade_NewStorageVariableWorks() public {
        vm.startPrank(s_admin);
        Upgrades.upgradeProxy(address(s_rwausd), "MockRwaUsdV2.sol", "");
        MockRwaUsdV2 tokenV2 = MockRwaUsdV2(address(s_rwausd));
        tokenV2.setNewVariable(42);
        assertEq(tokenV2.newVariable(), 42);
        vm.stopPrank();
    }

    function test_Upgrade_RevertWhen_CallerDoesNotHaveUpgraderRole() public {
        address newImpl = address(new MockRwaUsdV2());

        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, s_alice, s_rwausd.UPGRADER_ROLE()
            )
        );

        vm.prank(s_alice);
        s_rwausd.upgradeToAndCall(newImpl, "");
    }

    function test_Upgrade_BalancesPreserved() public {
        vm.prank(s_minter);
        s_rwausd.mint(s_alice, AMOUNT);

        vm.startPrank(s_admin);
        Upgrades.upgradeProxy(address(s_rwausd), "MockRwaUsdV2.sol", "");
        vm.stopPrank();

        assertEq(s_rwausd.balanceOf(s_alice), AMOUNT);
    }

    function test_Upgrade_AdminRolePreserved() public {
        vm.startPrank(s_admin);
        Upgrades.upgradeProxy(address(s_rwausd), "MockRwaUsdV2.sol:MockRwaUsdV2", "");
        vm.stopPrank();

        assertTrue(MockRwaUsdV2(address(s_rwausd)).hasRole(s_rwausd.DEFAULT_ADMIN_ROLE(), s_admin));
    }

    function test_Upgrade_CcipAdminPreserved() public {
        vm.startPrank(s_admin);
        Upgrades.upgradeProxy(address(s_rwausd), "MockRwaUsdV2.sol:MockRwaUsdV2", "");
        vm.stopPrank();

        assertEq(MockRwaUsdV2(address(s_rwausd)).getCCIPAdmin(), s_admin);
    }

    function test_Upgrade_MinterRolePreserved() public {
        vm.startPrank(s_admin);
        Upgrades.upgradeProxy(address(s_rwausd), "MockRwaUsdV2.sol:MockRwaUsdV2", "");
        vm.stopPrank();

        assertTrue(MockRwaUsdV2(address(s_rwausd)).hasRole(s_rwausd.MINTER_ROLE(), s_minter));
    }

    function test_Upgrade_PausedStatePreserved() public {
        vm.prank(s_pauser);
        s_rwausd.pause();

        vm.startPrank(s_admin);
        Upgrades.upgradeProxy(address(s_rwausd), "MockRwaUsdV2.sol", "");
        vm.stopPrank();

        assertTrue(MockRwaUsdV2(address(s_rwausd)).paused());
    }

    function test_Upgrade_AdminDelayPreserved() public {
        vm.startPrank(s_admin);
        Upgrades.upgradeProxy(address(s_rwausd), "MockRwaUsdV2.sol", "");
        vm.stopPrank();

        assertEq(MockRwaUsdV2(address(s_rwausd)).defaultAdminDelay(), ADMIN_DELAY);
    }

    function test_Upgrade_TimelockStillEnforcedAfterUpgrade() public {
        vm.startPrank(s_admin);
        Upgrades.upgradeProxy(address(s_rwausd), "MockRwaUsdV2.sol", "");
        vm.stopPrank();

        MockRwaUsdV2 tokenV2 = MockRwaUsdV2(address(s_rwausd));

        vm.prank(s_admin);
        tokenV2.beginDefaultAdminTransfer(s_alice);

        (, uint48 schedule) = tokenV2.pendingDefaultAdmin();
        vm.warp(schedule - 1);

        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControlDefaultAdminRules.AccessControlEnforcedDefaultAdminDelay.selector, schedule
            )
        );

        vm.prank(s_alice);
        tokenV2.acceptDefaultAdminTransfer();
    }

    // ================================================================
    // │                 Namespaced Storage Integrity                 │
    // ================================================================

    function test_Upgrade_Storage_DecimalsUnchanged() public {
        vm.startPrank(s_admin);
        Upgrades.upgradeProxy(address(s_rwausd), "MockRwaUsdV2.sol", "");
        vm.stopPrank();

        bytes32 rawSlot = vm.load(address(s_rwausd), SLOT_CCIP_DECIMALS);
        uint8 rawDecimals = uint8(uint256(rawSlot) >> 160);

        assertEq(rawDecimals, 18, "Storage slot+0 raw decimals != 18 after upgrade");
        assertEq(s_rwausd.decimals(), 18, "decimals() != 18 after upgrade");
    }

    function test_Upgrade_Storage_CcipAdminUnchanged() public {
        vm.startPrank(s_admin);
        Upgrades.upgradeProxy(address(s_rwausd), "MockRwaUsdV2.sol", "");
        vm.stopPrank();

        bytes32 rawSlot = vm.load(address(s_rwausd), SLOT_CCIP_DECIMALS);
        address rawCcipAdmin = address(uint160(uint256(rawSlot)));

        assertEq(rawCcipAdmin, s_admin, "Storage slot+0 raw ccipAdmin != s_admin after upgrade");
        assertEq(s_rwausd.getCCIPAdmin(), s_admin, "getCCIPAdmin() != s_admin after upgrade");
    }

    function test_Upgrade_Storage_MaxSupplyUnchanged() public {
        uint256 expectedMaxSupply = s_rwausd.maxSupply();

        vm.startPrank(s_admin);
        Upgrades.upgradeProxy(address(s_rwausd), "MockRwaUsdV2.sol", "");
        vm.stopPrank();

        uint256 rawMaxSupply = uint256(vm.load(address(s_rwausd), SLOT_MAX_SUPPLY));

        assertEq(rawMaxSupply, expectedMaxSupply, "Storage slot+1 raw maxSupply != expected after upgrade");
        assertEq(s_rwausd.maxSupply(), expectedMaxSupply, "maxSupply() != expected after upgrade");
        assertEq(
            MockRwaUsdV2(address(s_rwausd)).maxSupply(), expectedMaxSupply, "V2 maxSupply() != expected after upgrade"
        );
    }

    function test_Upgrade_Storage_NoSlotCollision() public {
        (bytes32 pre_m1, bytes32 pre_0, bytes32 pre_1, bytes32 pre_2) = _readNamespaceWindow(address(s_rwausd));

        vm.startPrank(s_admin);
        Upgrades.upgradeProxy(address(s_rwausd), "MockRwaUsdV2.sol", "");
        vm.stopPrank();

        (bytes32 post_m1, bytes32 post_0, bytes32 post_1, bytes32 post_2) = _readNamespaceWindow(address(s_rwausd));

        assertEq(pre_m1, post_m1, "Slot collision: slot before namespace was overwritten");
        assertEq(pre_0, post_0, "Slot collision: namespace slot+0 (ccipAdmin+decimals) was overwritten");
        assertEq(pre_1, post_1, "Slot collision: namespace slot+1 (maxSupply) was overwritten");
        assertEq(pre_2, post_2, "Slot collision: namespace slot+2 (reserved/future) was overwritten");
    }

    function test_Upgrade_Storage_ERC20BalancesIntact() public {
        vm.prank(s_minter);
        s_rwausd.mint(s_alice, 500e18);
        vm.prank(s_minter);
        s_rwausd.mint(s_bob, 250e18);

        uint256 supplyBefore = s_rwausd.totalSupply();
        uint256 aliceBefore = s_rwausd.balanceOf(s_alice);
        uint256 bobBefore = s_rwausd.balanceOf(s_bob);

        vm.startPrank(s_admin);
        Upgrades.upgradeProxy(address(s_rwausd), "MockRwaUsdV2.sol", "");
        vm.stopPrank();

        assertEq(s_rwausd.totalSupply(), supplyBefore, "totalSupply changed after upgrade");
        assertEq(s_rwausd.balanceOf(s_alice), aliceBefore, "s_alice balance changed after upgrade");
        assertEq(s_rwausd.balanceOf(s_bob), bobBefore, "s_bob balance changed after upgrade");
    }

    function test_Upgrade_Storage_V2StorageDoesNotCollideWithNamespace() public {
        vm.startPrank(s_admin);
        Upgrades.upgradeProxy(address(s_rwausd), "MockRwaUsdV2.sol", "");
        vm.stopPrank();

        uint256 expectedMaxSupply = MockRwaUsdV2(address(s_rwausd)).maxSupply();
        MockRwaUsdV2(address(s_rwausd)).setNewVariable(12345);

        bytes32 rawSlot1 = vm.load(address(s_rwausd), SLOT_CCIP_DECIMALS);
        uint8 rawDecimals = uint8(uint256(rawSlot1) >> 160);
        address rawCcipAdmin = address(uint160(uint256(rawSlot1)));
        uint256 rawMaxSupply = uint256(vm.load(address(s_rwausd), SLOT_MAX_SUPPLY));

        assertEq(rawDecimals, 18, "V2 write collided with namespace slot+0: decimals != 18");
        assertEq(rawCcipAdmin, s_admin, "V2 write collided with namespace slot+0: ccipAdmin != s_admin");
        assertEq(rawMaxSupply, expectedMaxSupply, "V2 write collided with namespace slot+1: maxSupply changed");
        assertEq(MockRwaUsdV2(address(s_rwausd)).newVariable(), 12345, "V2 newVariable not stored correctly");
    }

    function test_Upgrade_Storage_SlotConstantMatchesERC7201Formula() public pure {
        bytes32 computed =
            keccak256(abi.encode(uint256(keccak256("multipli.storage.rwaUSD")) - 1)) & ~bytes32(uint256(0xff));

        assertEq(computed, RWAUSD_STORAGE_LOCATION, "RWAUSD_STORAGE_LOCATION constant does not match ERC-7201 formula");
    }
}
