// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {RwaUsd} from "src/token/RwaUsd.sol";
import {MockRwaUsdV2} from "./mocks/MockRwaUsdV2.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {
    IAccessControlDefaultAdminRules
} from "@openzeppelin/contracts/access/extensions/IAccessControlDefaultAdminRules.sol";
import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";

contract RwaUsdTest is Test {
    RwaUsd internal token;

    address internal admin = makeAddr("admin");
    address internal minter = makeAddr("minter");
    address internal burner = makeAddr("burner");
    address internal pauser = makeAddr("pauser");
    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");
    address internal deployer = makeAddr("deployer");

    /// @dev 1 hour delay configured in RwaUsd initialize
    uint48 internal constant ADMIN_DELAY = 1 hours;

    /// @dev The ERC-7201 storage slot for RwaUsdStorage:
    ///      keccak256(abi.encode(uint256(keccak256("multipli.storage.RwaUsdStorage")) - 1)) & ~bytes32(uint256(0xff))
    ///
    ///      Struct layout (ERC-7201):
    ///        slot+0  → address ccipAdmin (low 160 bits) + uint8 decimals (bits 160–167), packed
    ///        slot+1  → uint256 maxSupply
    bytes32 internal constant BURN_MINT_ERC20_STORAGE_SLOT =
        0x82cef61f4c40d7d5e0ccbca8de5ddf691aeb2979bdbd13bd1e8748d660c9ef00;

    // ================================================================
    // │                          Helpers                             │
    // ================================================================

    function _expectAccessControlRevert(address account, bytes32 role) internal {
        vm.expectRevert(abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, account, role));
    }

    function _expectMaxSupplyExceededRevert(uint256 amount) internal {
        vm.expectRevert(abi.encodeWithSelector(bytes4(keccak256("RwaUsd__MaxSupplyExceeded(uint256)")), amount));
    }

    function _expectInvalidRecipientRevert(address recipient) internal {
        vm.expectRevert(abi.encodeWithSelector(bytes4(keccak256("RwaUsd__InvalidRecipient(address)")), recipient));
    }

    function _expectEnforcedPauseRevert() internal {
        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
    }

    function _expectEnforcedDefaultAdminDelayRevert(uint48 schedule) internal {
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControlDefaultAdminRules.AccessControlEnforcedDefaultAdminDelay.selector, schedule
            )
        );
    }

    function _expectEnforcedDefaultAdminRulesRevert() internal {
        vm.expectRevert(IAccessControlDefaultAdminRules.AccessControlEnforcedDefaultAdminRules.selector);
    }

    function _expectInvalidDefaultAdminRevert(address account) internal {
        vm.expectRevert(
            abi.encodeWithSelector(IAccessControlDefaultAdminRules.AccessControlInvalidDefaultAdmin.selector, account)
        );
    }

    /// @dev Completes a full admin transfer from `currentAdmin` to `newAdmin`,
    ///      warping past the delay. Leaves msg.sender as newAdmin after completion.
    function _completeAdminTransfer(address currentAdmin, address newAdmin) internal {
        vm.prank(currentAdmin);
        token.beginDefaultAdminTransfer(newAdmin);

        (, uint48 schedule) = token.pendingDefaultAdmin();
        vm.warp(schedule + 1);

        vm.prank(newAdmin);
        token.acceptDefaultAdminTransfer();
    }

    function setUp() public {
        vm.startPrank(deployer);

        bytes memory data = abi.encodeCall(
            RwaUsd.initialize,
            (
                "Real World Asset USD",
                "rwaUSD",
                uint8(18),
                0, // maxSupply (unlimited)
                0, // preMint
                admin,
                admin // defaultUpgrader
            )
        );

        address proxy = Upgrades.deployUUPSProxy("RwaUsd.sol", data);
        token = RwaUsd(address(proxy));
        vm.stopPrank();

        vm.startPrank(admin);
        token.grantRole(token.MINTER_ROLE(), minter);
        token.grantRole(token.BURNER_ROLE(), burner);
        token.grantRole(token.PAUSER_ROLE(), pauser);
        vm.stopPrank();
    }

    // ================================================================
    // │                        Initialize                            │
    // ================================================================

    function test_initialize_AdminSetCorrectly() public view {
        assertTrue(token.hasRole(token.DEFAULT_ADMIN_ROLE(), admin));
    }

    function test_initialize_DeployerRoleRevoked() public view {
        assertFalse(token.hasRole(token.DEFAULT_ADMIN_ROLE(), deployer));
    }

    function test_initialize_CcipAdminSetCorrectly() public view {
        assertEq(token.getCCIPAdmin(), admin);
    }

    function test_initialize_NameSetCorrectly() public view {
        assertEq(token.name(), "Real World Asset USD");
    }

    function test_initialize_SymbolSetCorrectly() public view {
        assertEq(token.symbol(), "rwaUSD");
    }

    function test_initialize_DecimalsSetCorrectly() public view {
        assertEq(token.decimals(), 18);
    }

    function test_initialize_MaxSupplySetCorrectly() public view {
        assertEq(token.maxSupply(), 0);
    }

    function test_initialize_TotalSupplyIsZero() public view {
        assertEq(token.totalSupply(), 0);
    }

    function test_initialize_MinterRoleSetCorrectly() public view {
        assertTrue(token.hasRole(token.MINTER_ROLE(), minter));
    }

    function test_initialize_BurnerRoleSetCorrectly() public view {
        assertTrue(token.hasRole(token.BURNER_ROLE(), burner));
    }

    function test_initialize_PauserRoleSetCorrectly() public view {
        assertTrue(token.hasRole(token.PAUSER_ROLE(), pauser));
    }

    function test_initialize_UpgraderRoleSetCorrectly() public view {
        assertTrue(token.hasRole(token.UPGRADER_ROLE(), admin));
    }

    function test_initialize_DefaultAdminDelaySetCorrectly() public view {
        assertEq(token.defaultAdminDelay(), ADMIN_DELAY);
    }

    function test_initialize_DefaultAdminSetCorrectly() public view {
        assertEq(token.defaultAdmin(), admin);
    }

    function test_initialize_RevertsIfCalledAgain() public {
        vm.expectRevert(Initializable.InvalidInitialization.selector);
        token.initialize("Real World Asset USD", "rwaUSD", 18, 0, 0, alice, alice);
    }

    function test_initialize_RevertsIfAdminIsZeroAddress() public {
        address implementation = address(new RwaUsd());
        _expectInvalidDefaultAdminRevert(address(0));
        new ERC1967Proxy(
            implementation,
            abi.encodeCall(RwaUsd.initialize, ("Real World Asset USD", "rwaUSD", 18, 0, 0, address(0), address(0)))
        );
    }

    function test_initialize_PreMintSentToAdmin() public {
        address implementation = address(new RwaUsd());
        ERC1967Proxy proxy = new ERC1967Proxy(
            implementation,
            abi.encodeCall(RwaUsd.initialize, ("Real World Asset USD", "rwaUSD", 18, 1000e18, 100e18, admin, admin))
        );
        RwaUsd newToken = RwaUsd(address(proxy));
        assertEq(newToken.balanceOf(admin), 100e18);
        assertEq(newToken.totalSupply(), 100e18);
    }

    function test_initialize_RevertsIfPreMintExceedsMaxSupply() public {
        address implementation = address(new RwaUsd());
        _expectMaxSupplyExceededRevert(200e18);
        new ERC1967Proxy(
            implementation,
            abi.encodeCall(RwaUsd.initialize, ("Real World Asset USD", "rwaUSD", 18, 100e18, 200e18, admin, admin))
        );
    }

    // ================================================================
    // │                         Minting                              │
    // ================================================================

    function test_mint_SuccessWhenCalledByMinter() public {
        vm.prank(minter);
        token.mint(alice, 100e18);
        assertEq(token.balanceOf(alice), 100e18);
        assertEq(token.totalSupply(), 100e18);
    }

    function test_mint_RevertsWhenCalledByNonMinter() public {
        _expectAccessControlRevert(alice, token.MINTER_ROLE());
        vm.prank(alice);
        token.mint(alice, 100e18);
    }

    function test_mint_RevertsWhenMaxSupplyExceeded() public {
        vm.startPrank(admin);
        address implementation = address(new RwaUsd());
        ERC1967Proxy proxy = new ERC1967Proxy(
            implementation,
            abi.encodeCall(RwaUsd.initialize, ("Real World Asset USD", "rwaUSD", 18, 1000e18, 0, admin, admin))
        );
        RwaUsd cappedToken = RwaUsd(address(proxy));
        cappedToken.grantRole(cappedToken.MINTER_ROLE(), minter);
        vm.stopPrank();

        _expectMaxSupplyExceededRevert(1001e18);
        vm.prank(minter);
        cappedToken.mint(alice, 1001e18);
    }

    function test_mint_RevertsToAddressThis() public {
        _expectInvalidRecipientRevert(address(token));
        vm.prank(minter);
        token.mint(address(token), 100e18);
    }

    // ================================================================
    // │                         Burning                              │
    // ================================================================

    function test_burn_SuccessWhenCalledByBurner() public {
        vm.prank(minter);
        token.mint(burner, 100e18);

        vm.prank(burner);
        token.burn(50e18);
        assertEq(token.balanceOf(burner), 50e18);
        assertEq(token.totalSupply(), 50e18);
    }

    function test_burn_RevertsWhenCalledByNonBurner() public {
        vm.prank(minter);
        token.mint(alice, 100e18);

        _expectAccessControlRevert(alice, token.BURNER_ROLE());
        vm.prank(alice);
        token.burn(50e18);
    }

    function test_burnFrom_SuccessWhenCalledByBurner() public {
        vm.prank(minter);
        token.mint(alice, 100e18);

        vm.prank(alice);
        token.approve(burner, 50e18);

        vm.prank(burner);
        token.burnFrom(alice, 50e18);
        assertEq(token.balanceOf(alice), 50e18);
        assertEq(token.totalSupply(), 50e18);
    }

    function test_burnFrom_RevertsWhenCalledByNonBurner() public {
        vm.prank(minter);
        token.mint(alice, 100e18);

        _expectAccessControlRevert(alice, token.BURNER_ROLE());
        vm.prank(alice);
        token.burnFrom(alice, 50e18);
    }

    // ================================================================
    // │                         Pausable                             │
    // ================================================================

    function test_pause_SuccessWhenCalledByPauser() public {
        vm.prank(pauser);
        token.pause();
        assertTrue(token.paused());
    }

    function test_pause_RevertsWhenCalledByNonPauser() public {
        _expectAccessControlRevert(alice, token.PAUSER_ROLE());
        vm.prank(alice);
        token.pause();
    }

    function test_unpause_SuccessWhenCalledByAdmin() public {
        vm.prank(pauser);
        token.pause();

        vm.prank(admin);
        token.unpause();
        assertFalse(token.paused());
    }

    function test_unpause_RevertsWhenCalledByNonAdmin() public {
        vm.prank(pauser);
        token.pause();

        _expectAccessControlRevert(pauser, token.DEFAULT_ADMIN_ROLE());
        vm.prank(pauser);
        token.unpause();
    }

    function test_pause_BlocksMinting() public {
        vm.prank(pauser);
        token.pause();

        _expectEnforcedPauseRevert();
        vm.prank(minter);
        token.mint(alice, 100e18);
    }

    function test_pause_BlocksBurning() public {
        vm.prank(minter);
        token.mint(burner, 100e18);

        vm.prank(pauser);
        token.pause();

        _expectEnforcedPauseRevert();
        vm.prank(burner);
        token.burn(50e18);
    }

    function test_pause_BlocksTransfers() public {
        vm.prank(minter);
        token.mint(alice, 100e18);

        vm.prank(pauser);
        token.pause();

        _expectEnforcedPauseRevert();
        vm.prank(alice);
        token.transfer(bob, 50e18);
    }

    function test_pause_BlocksApprovals() public {
        vm.prank(pauser);
        token.pause();

        _expectEnforcedPauseRevert();
        vm.prank(alice);
        token.approve(bob, 100e18);
    }

    function test_unpause_RestoresMinting() public {
        vm.prank(pauser);
        token.pause();

        vm.prank(admin);
        token.unpause();

        vm.prank(minter);
        token.mint(alice, 100e18);
        assertEq(token.balanceOf(alice), 100e18);
    }

    function test_unpause_RestoresTransfers() public {
        vm.prank(minter);
        token.mint(alice, 100e18);

        vm.prank(pauser);
        token.pause();

        vm.prank(admin);
        token.unpause();

        vm.prank(alice);
        token.transfer(bob, 50e18);
        assertEq(token.balanceOf(bob), 50e18);
    }

    // ================================================================
    // │                   Default Admin Timelock                     │
    // ================================================================

    /// @dev grantRole(DEFAULT_ADMIN_ROLE) is blocked even when called by the current admin.
    ///      The call passes the onlyRole(DEFAULT_ADMIN_ROLE) check on admin, then hits
    ///      AccessControlEnforcedDefaultAdminRules inside grantRole.
    function test_adminTransfer_RevertsIfDefaultAdminRoleGrantedDirectly() public {
        vm.startPrank(admin);
        (bool success, bytes memory returnData) =
            address(token).call(abi.encodeWithSelector(token.grantRole.selector, token.DEFAULT_ADMIN_ROLE(), alice));
        vm.stopPrank();

        assertFalse(success, "grantRole(DEFAULT_ADMIN_ROLE) should have reverted");
        assertEq(
            bytes4(returnData),
            IAccessControlDefaultAdminRules.AccessControlEnforcedDefaultAdminRules.selector,
            "unexpected revert selector"
        );
    }

    /// @dev revokeRole(DEFAULT_ADMIN_ROLE) is blocked even when called by the current admin.
    function test_adminTransfer_RevertsIfDefaultAdminRoleRevokedDirectly() public {
        vm.startPrank(admin);
        (bool success, bytes memory returnData) =
            address(token).call(abi.encodeWithSelector(token.revokeRole.selector, token.DEFAULT_ADMIN_ROLE(), admin));
        vm.stopPrank();

        assertFalse(success, "revokeRole(DEFAULT_ADMIN_ROLE) should have reverted");
        assertEq(
            bytes4(returnData),
            IAccessControlDefaultAdminRules.AccessControlEnforcedDefaultAdminRules.selector,
            "unexpected revert selector"
        );
    }

    function test_adminTransfer_BeginTransferSetsPendingAdmin() public {
        vm.prank(admin);
        token.beginDefaultAdminTransfer(alice);

        (address pendingAdmin, uint48 schedule) = token.pendingDefaultAdmin();
        assertEq(pendingAdmin, alice);
        assertGt(schedule, block.timestamp);
    }

    function test_adminTransfer_RevertsIfBeginTransferCalledByNonAdmin() public {
        _expectAccessControlRevert(alice, token.DEFAULT_ADMIN_ROLE());
        vm.prank(alice);
        token.beginDefaultAdminTransfer(bob);
    }

    function test_adminTransfer_RevertsIfAcceptedBeforeDelayPasses() public {
        vm.prank(admin);
        token.beginDefaultAdminTransfer(alice);

        (, uint48 schedule) = token.pendingDefaultAdmin();

        vm.warp(schedule - 1);

        _expectEnforcedDefaultAdminDelayRevert(schedule);
        vm.prank(alice);
        token.acceptDefaultAdminTransfer();
    }

    function test_adminTransfer_SuccessAfterDelayPasses() public {
        _completeAdminTransfer(admin, alice);

        assertEq(token.defaultAdmin(), alice);
        assertFalse(token.hasRole(token.DEFAULT_ADMIN_ROLE(), admin));
        assertTrue(token.hasRole(token.DEFAULT_ADMIN_ROLE(), alice));
    }

    function test_adminTransfer_RevertsIfAcceptedByWrongAccount() public {
        vm.prank(admin);
        token.beginDefaultAdminTransfer(alice);

        (, uint48 schedule) = token.pendingDefaultAdmin();
        vm.warp(schedule + 1);

        _expectInvalidDefaultAdminRevert(bob);
        vm.prank(bob);
        token.acceptDefaultAdminTransfer();
    }

    function test_adminTransfer_CancelClearsPendingAdmin() public {
        vm.prank(admin);
        token.beginDefaultAdminTransfer(alice);

        vm.prank(admin);
        token.cancelDefaultAdminTransfer();

        (address pendingAdmin, uint48 schedule) = token.pendingDefaultAdmin();
        assertEq(pendingAdmin, address(0));
        assertEq(schedule, 0);
    }

    function test_adminTransfer_RevertsIfCancelCalledByNonAdmin() public {
        vm.prank(admin);
        token.beginDefaultAdminTransfer(alice);

        _expectAccessControlRevert(alice, token.DEFAULT_ADMIN_ROLE());
        vm.prank(alice);
        token.cancelDefaultAdminTransfer();
    }

    function test_adminTransfer_CancelledTransferCannotBeAccepted() public {
        vm.prank(admin);
        token.beginDefaultAdminTransfer(alice);

        (, uint48 schedule) = token.pendingDefaultAdmin();

        vm.prank(admin);
        token.cancelDefaultAdminTransfer();

        vm.warp(schedule + 1);

        // pendingAdmin is address(0) after cancel so alice cannot accept
        _expectInvalidDefaultAdminRevert(alice);
        vm.prank(alice);
        token.acceptDefaultAdminTransfer();
    }

    function test_adminTransfer_OldAdminLosesRoleAfterTransfer() public {
        _completeAdminTransfer(admin, alice);

        _expectAccessControlRevert(admin, token.DEFAULT_ADMIN_ROLE());
        vm.prank(admin);
        token.setCCIPAdmin(bob);
    }

    function test_adminTransfer_NewAdminCanGrantRoles() public {
        _completeAdminTransfer(admin, alice);

        assertEq(token.defaultAdmin(), alice, "alice should be default admin after transfer");

        vm.startPrank(alice);
        token.grantRole(token.MINTER_ROLE(), bob);
        assertTrue(token.hasRole(token.MINTER_ROLE(), bob));
        vm.stopPrank();
    }

    function test_adminTransfer_NewAdminCanCallAdminGatedFunctions() public {
        _completeAdminTransfer(admin, alice);

        vm.prank(alice);
        token.setCCIPAdmin(bob);
        assertEq(token.getCCIPAdmin(), bob);
    }

    function test_adminTransfer_PendingAdminUpdatedOnSecondBeginTransfer() public {
        vm.prank(admin);
        token.beginDefaultAdminTransfer(alice);

        vm.prank(admin);
        token.beginDefaultAdminTransfer(bob);

        (address pendingAdmin,) = token.pendingDefaultAdmin();
        assertEq(pendingAdmin, bob);
    }

    function test_adminTransfer_DelayIsRespectedOnNewTransfer() public {
        _completeAdminTransfer(admin, alice);

        // alice starts a transfer to bob — delay should still be enforced
        vm.prank(alice);
        token.beginDefaultAdminTransfer(bob);

        (, uint48 schedule) = token.pendingDefaultAdmin();
        vm.warp(schedule - 1);

        _expectEnforcedDefaultAdminDelayRevert(schedule);
        vm.prank(bob);
        token.acceptDefaultAdminTransfer();
    }

    // ================================================================
    // │                   Admin Delay Change                         │
    // ================================================================

    function test_adminDelay_ChangeScheduledCorrectly() public {
        uint48 newDelay = 2 hours;

        vm.prank(admin);
        token.changeDefaultAdminDelay(newDelay);

        (uint48 pendingDelay, uint48 schedule) = token.pendingDefaultAdminDelay();
        assertEq(pendingDelay, newDelay);
        assertGt(schedule, block.timestamp);
    }

    function test_adminDelay_RevertsIfChangeCalledByNonAdmin() public {
        _expectAccessControlRevert(alice, token.DEFAULT_ADMIN_ROLE());
        vm.prank(alice);
        token.changeDefaultAdminDelay(2 hours);
    }

    function test_adminDelay_NewDelayTakesEffectAfterSchedule() public {
        uint48 newDelay = 2 hours;

        vm.prank(admin);
        token.changeDefaultAdminDelay(newDelay);

        (, uint48 schedule) = token.pendingDefaultAdminDelay();
        vm.warp(schedule + 1);

        // Trigger materialization by starting a new admin transfer
        vm.prank(admin);
        token.beginDefaultAdminTransfer(alice);

        assertEq(token.defaultAdminDelay(), newDelay);
    }

    function test_adminDelay_RollbackRestoresPreviousDelay() public {
        uint48 originalDelay = token.defaultAdminDelay();

        vm.prank(admin);
        token.changeDefaultAdminDelay(2 hours);

        vm.prank(admin);
        token.rollbackDefaultAdminDelay();

        assertEq(token.defaultAdminDelay(), originalDelay);
    }

    function test_adminDelay_RevertsIfRollbackCalledByNonAdmin() public {
        _expectAccessControlRevert(alice, token.DEFAULT_ADMIN_ROLE());
        vm.prank(alice);
        token.rollbackDefaultAdminDelay();
    }

    // ================================================================
    // │                        CCIP Admin                            │
    // ================================================================

    function test_setCCIPAdmin_SuccessWhenCalledByAdmin() public {
        vm.prank(admin);
        token.setCCIPAdmin(alice);
        assertEq(token.getCCIPAdmin(), alice);
    }

    function test_setCCIPAdmin_RevertsWhenCalledByNonAdmin() public {
        _expectAccessControlRevert(alice, token.DEFAULT_ADMIN_ROLE());
        vm.prank(alice);
        token.setCCIPAdmin(alice);
    }

    function test_setCCIPAdmin_CanBeSetToZeroAddress() public {
        vm.prank(admin);
        token.setCCIPAdmin(address(0));
        assertEq(token.getCCIPAdmin(), address(0));
    }

    function test_setCCIPAdmin_EmitsEvent() public {
        vm.prank(admin);
        vm.expectEmit(true, true, false, false);
        emit RwaUsd.CCIPAdminTransferred(admin, alice);
        token.setCCIPAdmin(alice);
    }

    // ================================================================
    // │                          Upgrade                             │
    // ================================================================

    function test_upgrade_SuccessWhenCalledByUpgrader() public {
        vm.startPrank(admin);
        Upgrades.upgradeProxy(address(token), "MockRwaUsdV2.sol", "");
        vm.stopPrank();

        string memory response = MockRwaUsdV2(address(token)).newMethod();
        assertEq(response, "new method");
    }

    function test_upgrade_NewStorageVariableWorks() public {
        vm.startPrank(admin);
        Upgrades.upgradeProxy(address(token), "MockRwaUsdV2.sol", "");
        MockRwaUsdV2 tokenV2 = MockRwaUsdV2(address(token));
        tokenV2.setNewVariable(42);
        assertEq(tokenV2.newVariable(), 42);
        vm.stopPrank();
    }

    function test_upgrade_RevertsWhenCalledByNonUpgrader() public {
        address newImpl = address(new MockRwaUsdV2());
        _expectAccessControlRevert(alice, token.UPGRADER_ROLE());
        vm.prank(alice);
        token.upgradeToAndCall(newImpl, "");
    }

    function test_upgrade_BalancesPreserved() public {
        vm.prank(minter);
        token.mint(alice, 100e18);

        vm.startPrank(admin);
        Upgrades.upgradeProxy(address(token), "MockRwaUsdV2.sol", "");
        vm.stopPrank();

        assertEq(token.balanceOf(alice), 100e18);
    }

    function test_upgrade_AdminRolePreserved() public {
        vm.startPrank(admin);
        Upgrades.upgradeProxy(address(token), "MockRwaUsdV2.sol:MockRwaUsdV2", "");
        vm.stopPrank();

        assertTrue(MockRwaUsdV2(address(token)).hasRole(token.DEFAULT_ADMIN_ROLE(), admin));
    }

    function test_upgrade_CcipAdminPreserved() public {
        vm.startPrank(admin);
        Upgrades.upgradeProxy(address(token), "MockRwaUsdV2.sol:MockRwaUsdV2", "");
        vm.stopPrank();

        assertEq(MockRwaUsdV2(address(token)).getCCIPAdmin(), admin);
    }

    function test_upgrade_MinterRolePreserved() public {
        vm.startPrank(admin);
        Upgrades.upgradeProxy(address(token), "MockRwaUsdV2.sol:MockRwaUsdV2", "");
        vm.stopPrank();

        assertTrue(MockRwaUsdV2(address(token)).hasRole(token.MINTER_ROLE(), minter));
    }

    function test_upgrade_PausedStatePreserved() public {
        vm.prank(pauser);
        token.pause();

        vm.startPrank(admin);
        Upgrades.upgradeProxy(address(token), "MockRwaUsdV2.sol", "");
        vm.stopPrank();

        assertTrue(MockRwaUsdV2(address(token)).paused());
    }

    function test_upgrade_AdminDelayPreserved() public {
        vm.startPrank(admin);
        Upgrades.upgradeProxy(address(token), "MockRwaUsdV2.sol", "");
        vm.stopPrank();

        assertEq(MockRwaUsdV2(address(token)).defaultAdminDelay(), ADMIN_DELAY);
    }

    function test_upgrade_TimelockStillEnforcedAfterUpgrade() public {
        vm.startPrank(admin);
        Upgrades.upgradeProxy(address(token), "MockRwaUsdV2.sol", "");
        vm.stopPrank();

        MockRwaUsdV2 tokenV2 = MockRwaUsdV2(address(token));

        vm.prank(admin);
        tokenV2.beginDefaultAdminTransfer(alice);

        (, uint48 schedule) = tokenV2.pendingDefaultAdmin();

        vm.warp(schedule - 1);
        _expectEnforcedDefaultAdminDelayRevert(schedule);
        vm.prank(alice);
        tokenV2.acceptDefaultAdminTransfer();
    }

    // ================================================================
    // │                 Namespaced Storage Integrity                 │
    // ================================================================

    /// @dev Reads raw slot values in a window around the RwaUsdStorage namespace.
    ///
    ///      Struct layout (ERC-7201):
    ///        slot+0  → address ccipAdmin (low 160 bits) + uint8 decimals (bits 160-167), packed
    ///        slot+1  → uint256 maxSupply
    function _readNamespaceWindow(address proxy)
        internal
        view
        returns (bytes32 slotMinus1, bytes32 slot0, bytes32 slot1, bytes32 slot2)
    {
        slotMinus1 = vm.load(proxy, bytes32(uint256(BURN_MINT_ERC20_STORAGE_SLOT) - 1));
        slot0 = vm.load(proxy, BURN_MINT_ERC20_STORAGE_SLOT);
        slot1 = vm.load(proxy, bytes32(uint256(BURN_MINT_ERC20_STORAGE_SLOT) + 1));
        slot2 = vm.load(proxy, bytes32(uint256(BURN_MINT_ERC20_STORAGE_SLOT) + 2));
    }

    function test_upgrade_storage_DecimalsUnchanged() public {
        vm.startPrank(admin);
        Upgrades.upgradeProxy(address(token), "MockRwaUsdV2.sol", "");
        vm.stopPrank();

        bytes32 rawSlot = vm.load(address(token), BURN_MINT_ERC20_STORAGE_SLOT);

        uint8 rawDecimals = uint8(uint256(rawSlot) >> 160);
        assertEq(rawDecimals, 18, "Storage slot+0 raw decimals != 18 after upgrade");
        assertEq(token.decimals(), 18, "decimals() != 18 after upgrade");
    }

    function test_upgrade_storage_CcipAdminUnchanged() public {
        vm.startPrank(admin);
        Upgrades.upgradeProxy(address(token), "MockRwaUsdV2.sol", "");
        vm.stopPrank();

        bytes32 rawSlot = vm.load(address(token), BURN_MINT_ERC20_STORAGE_SLOT);

        address rawCcipAdmin = address(uint160(uint256(rawSlot)));
        assertEq(rawCcipAdmin, admin, "Storage slot+0 raw ccipAdmin != admin after upgrade");
        assertEq(token.getCCIPAdmin(), admin, "getCCIPAdmin() != admin after upgrade");
    }

    function test_upgrade_storage_MaxSupplyUnchanged() public {
        uint256 expectedMaxSupply = token.maxSupply();

        vm.startPrank(admin);
        Upgrades.upgradeProxy(address(token), "MockRwaUsdV2.sol", "");
        vm.stopPrank();

        uint256 rawMaxSupply = uint256(vm.load(address(token), bytes32(uint256(BURN_MINT_ERC20_STORAGE_SLOT) + 1)));
        assertEq(rawMaxSupply, expectedMaxSupply, "Storage slot+1 raw maxSupply != expected after upgrade");
        assertEq(token.maxSupply(), expectedMaxSupply, "maxSupply() != expected after upgrade");
        assertEq(
            MockRwaUsdV2(address(token)).maxSupply(), expectedMaxSupply, "V2 maxSupply() != expected after upgrade"
        );
    }

    function test_upgrade_storage_NoSlotCollision() public {
        (bytes32 pre_m1, bytes32 pre_0, bytes32 pre_1, bytes32 pre_2) = _readNamespaceWindow(address(token));

        vm.startPrank(admin);
        Upgrades.upgradeProxy(address(token), "MockRwaUsdV2.sol", "");
        vm.stopPrank();

        (bytes32 post_m1, bytes32 post_0, bytes32 post_1, bytes32 post_2) = _readNamespaceWindow(address(token));

        assertEq(pre_m1, post_m1, "Slot collision: slot before namespace was overwritten");
        assertEq(pre_0, post_0, "Slot collision: namespace slot+0 (ccipAdmin+decimals) was overwritten");
        assertEq(pre_1, post_1, "Slot collision: namespace slot+1 (maxSupply) was overwritten");
        assertEq(pre_2, post_2, "Slot collision: namespace slot+2 (reserved/future) was overwritten");
    }

    function test_upgrade_storage_ERC20BalancesIntact() public {
        vm.prank(minter);
        token.mint(alice, 500e18);
        vm.prank(minter);
        token.mint(bob, 250e18);

        uint256 supplyBefore = token.totalSupply();
        uint256 aliceBefore = token.balanceOf(alice);
        uint256 bobBefore = token.balanceOf(bob);

        vm.startPrank(admin);
        Upgrades.upgradeProxy(address(token), "MockRwaUsdV2.sol", "");
        vm.stopPrank();

        assertEq(token.totalSupply(), supplyBefore, "totalSupply changed after upgrade");
        assertEq(token.balanceOf(alice), aliceBefore, "alice balance changed after upgrade");
        assertEq(token.balanceOf(bob), bobBefore, "bob balance changed after upgrade");
    }

    function test_upgrade_storage_V2StorageDoesNotCollideWithNamespace() public {
        vm.startPrank(admin);
        Upgrades.upgradeProxy(address(token), "MockRwaUsdV2.sol", "");
        vm.stopPrank();

        uint256 expectedMaxSupply = MockRwaUsdV2(address(token)).maxSupply();
        MockRwaUsdV2(address(token)).setNewVariable(12345);

        bytes32 rawSlot0 = vm.load(address(token), BURN_MINT_ERC20_STORAGE_SLOT);
        uint8 rawDecimals = uint8(uint256(rawSlot0) >> 160);
        address rawCcipAdmin = address(uint160(uint256(rawSlot0)));
        uint256 rawMaxSupply = uint256(vm.load(address(token), bytes32(uint256(BURN_MINT_ERC20_STORAGE_SLOT) + 1)));

        assertEq(rawDecimals, 18, "V2 write collided with namespace slot+0: decimals != 18");
        assertEq(rawCcipAdmin, admin, "V2 write collided with namespace slot+0: ccipAdmin != admin");
        assertEq(rawMaxSupply, expectedMaxSupply, "V2 write collided with namespace slot+1: maxSupply changed");
        assertEq(MockRwaUsdV2(address(token)).newVariable(), 12345, "V2 newVariable not stored correctly");
    }

    function test_upgrade_storage_SlotConstantMatchesERC7201Formula() public pure {
        bytes32 computed =
            keccak256(abi.encode(uint256(keccak256("multipli.storage.RwaUsd")) - 1)) & ~bytes32(uint256(0xff));

        assertEq(
            computed,
            BURN_MINT_ERC20_STORAGE_SLOT,
            "BURN_MINT_ERC20_STORAGE_SLOT constant does not match ERC-7201 formula"
        );
    }
}
