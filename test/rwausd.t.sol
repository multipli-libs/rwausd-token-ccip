// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import {Test} from "forge-std/Test.sol";
import {RwaUsd} from "src/token/RwaUsd.sol";
import {MockRwaUsdV2} from "./mocks/MockRwaUsdV2.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract RwaUsdTest is Test {
    RwaUsd internal token;

    address internal admin = makeAddr("admin");
    address internal minter = makeAddr("minter");
    address internal burner = makeAddr("burner");
    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");
    address internal deployer = makeAddr("deployer");

    function setUp() public {
        vm.startPrank(deployer);
        bytes memory data = abi.encodeWithSelector(RwaUsd.initialize.selector, admin);

        address proxy = Upgrades.deployUUPSProxy("RwaUsd.sol", data);

        token = RwaUsd(address(proxy));
        vm.stopPrank();

        // Grant minter and burner roles
        vm.startPrank(admin);
        token.grantRole(token.MINTER_ROLE(), minter);
        token.grantRole(token.BURNER_ROLE(), burner);
        vm.stopPrank();
    }

    // ================================================================
    // │                        Initialize                            │
    // ================================================================

    /**
     * @notice Admin is set correctly and deployer role is revoked
     */
    function test_initialize_AdminSetCorrectly() public view {
        assertTrue(token.hasRole(token.DEFAULT_ADMIN_ROLE(), admin));
    }

    /**
     * @notice Deployer should not retain DEFAULT_ADMIN_ROLE after initialize
     */
    function test_initialize_DeployerRoleRevoked() public view {
        assertFalse(token.hasRole(token.DEFAULT_ADMIN_ROLE(), deployer));
    }

    /**
     * @notice CCIP admin is set to the provided admin address
     */
    function test_initialize_CcipAdminSetCorrectly() public view {
        assertEq(token.getCCIPAdmin(), admin);
    }

    /**
     * @notice initialize cannot be called a second time
     */
    function test_initialize_RevertsIfCalledAgain() public {
        vm.expectRevert();
        token.initialize(alice);
    }

    /**
     * @notice initialize reverts if admin is address(0)
     */
    function test_initialize_RevertsIfAdminIsZeroAddress() public {
        address implementation = address(new RwaUsd());
        vm.expectRevert();
        new ERC1967Proxy(implementation, abi.encodeWithSelector(RwaUsd.initialize.selector, address(0)));
    }

    // ================================================================
    // │                     Pause & Unpause                          │
    // ================================================================

    /**
     * @notice Admin can pause transfers
     */
    function test_pauseTransfers_SuccessWhenCalledByAdmin() public {
        vm.prank(admin);
        token.pauseTransfers();
        assertTrue(token.transfersPaused());
    }

    /**
     * @notice Pausing emits the correct event
     */
    function test_pauseTransfers_EmitsEvent() public {
        vm.expectEmit(true, false, false, false);
        emit RwaUsd.TransfersPaused(admin);
        vm.prank(admin);
        token.pauseTransfers();
    }

    /**
     * @notice Non-admin cannot pause transfers
     */
    function test_pauseTransfers_RevertsWhenCalledByNonAdmin() public {
        vm.prank(alice);
        vm.expectRevert();
        token.pauseTransfers();
    }

    /**
     * @notice Admin can unpause transfers
     */
    function test_unpauseTransfers_SuccessWhenCalledByAdmin() public {
        vm.startPrank(admin);
        token.pauseTransfers();
        token.unpauseTransfers();
        vm.stopPrank();
        assertFalse(token.transfersPaused());
    }

    /**
     * @notice Unpausing emits the correct event
     */
    function test_unpauseTransfers_EmitsEvent() public {
        vm.prank(admin);
        token.pauseTransfers();

        vm.expectEmit(true, false, false, false);
        emit RwaUsd.TransfersUnpaused(admin);
        vm.prank(admin);
        token.unpauseTransfers();
    }

    /**
     * @notice Non-admin cannot unpause transfers
     */
    function test_unpauseTransfers_RevertsWhenCalledByNonAdmin() public {
        vm.prank(admin);
        token.pauseTransfers();

        vm.prank(alice);
        vm.expectRevert();
        token.unpauseTransfers();
    }

    /**
     * @notice Transfers revert when paused
     */
    function test_transfer_RevertsWhenPaused() public {
        vm.prank(minter);
        token.mint(alice, 100e18);

        vm.prank(admin);
        token.pauseTransfers();

        vm.prank(alice);
        vm.expectRevert(RwaUsd.TransfersArePaused.selector);
        token.transfer(bob, 100e18);
    }

    /**
     * @notice Mints revert when paused
     */
    function test_mint_RevertsWhenPaused() public {
        vm.prank(admin);
        token.pauseTransfers();

        vm.prank(minter);
        vm.expectRevert(RwaUsd.TransfersArePaused.selector);
        token.mint(alice, 100e18);
    }

    /**
     * @notice Burns revert when paused
     */
    function test_burn_RevertsWhenPaused() public {
        vm.prank(minter);
        token.mint(alice, 100e18);

        vm.prank(alice);
        token.approve(burner, 100e18);

        vm.prank(admin);
        token.pauseTransfers();

        vm.prank(burner);
        vm.expectRevert(RwaUsd.TransfersArePaused.selector);
        token.burn(alice, 100e18);
    }

    /**
     * @notice Transfers succeed after unpausing
     */
    function test_transfer_SuccessAfterUnpause() public {
        vm.prank(minter);
        token.mint(alice, 100e18);

        vm.startPrank(admin);
        token.pauseTransfers();
        token.unpauseTransfers();
        vm.stopPrank();

        vm.prank(alice);
        token.transfer(bob, 100e18);
        assertEq(token.balanceOf(bob), 100e18);
    }

    // ================================================================
    // │                        Blocklist                             │
    // ================================================================

    /**
     * @notice Admin can add an address to the blocklist
     */
    function test_addToBlocklist_SuccessWhenCalledByAdmin() public {
        vm.prank(admin);
        token.addToBlocklist(alice);
        assertTrue(token.isBlocklisted(alice));
    }

    /**
     * @notice Adding to blocklist emits the correct event
     */
    function test_addToBlocklist_EmitsEvent() public {
        vm.expectEmit(true, true, false, false);
        emit RwaUsd.AddressBlocklisted(alice, admin);
        vm.prank(admin);
        token.addToBlocklist(alice);
    }

    /**
     * @notice Non-admin cannot add to blocklist
     */
    function test_addToBlocklist_RevertsWhenCalledByNonAdmin() public {
        vm.prank(alice);
        vm.expectRevert();
        token.addToBlocklist(bob);
    }

    /**
     * @notice Admin can remove an address from the blocklist
     */
    function test_removeFromBlocklist_SuccessWhenCalledByAdmin() public {
        vm.startPrank(admin);
        token.addToBlocklist(alice);
        token.removeFromBlocklist(alice);
        vm.stopPrank();
        assertFalse(token.isBlocklisted(alice));
    }

    /**
     * @notice Removing from blocklist emits the correct event
     */
    function test_removeFromBlocklist_EmitsEvent() public {
        vm.prank(admin);
        token.addToBlocklist(alice);

        vm.expectEmit(true, true, false, false);
        emit RwaUsd.AddressUnblocklisted(alice, admin);
        vm.prank(admin);
        token.removeFromBlocklist(alice);
    }

    /**
     * @notice Non-admin cannot remove from blocklist
     */
    function test_removeFromBlocklist_RevertsWhenCalledByNonAdmin() public {
        vm.prank(admin);
        token.addToBlocklist(alice);

        vm.prank(alice);
        vm.expectRevert();
        token.removeFromBlocklist(alice);
    }

    /**
     * @notice Blocklisted sender cannot transfer tokens
     */
    function test_transfer_RevertsWhenSenderIsBlocklisted() public {
        vm.prank(minter);
        token.mint(alice, 100e18);

        vm.prank(admin);
        token.addToBlocklist(alice);

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(RwaUsd.AddressIsBlocklisted.selector, alice));
        token.transfer(bob, 100e18);
    }

    /**
     * @notice Blocklisted recipient cannot receive tokens
     */
    function test_transfer_RevertsWhenRecipientIsBlocklisted() public {
        vm.prank(minter);
        token.mint(alice, 100e18);

        vm.prank(admin);
        token.addToBlocklist(bob);

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(RwaUsd.AddressIsBlocklisted.selector, bob));
        token.transfer(bob, 100e18);
    }

    /**
     * @notice Minting to a blocklisted address reverts
     */
    function test_mint_RevertsWhenRecipientIsBlocklisted() public {
        vm.prank(admin);
        token.addToBlocklist(alice);

        vm.prank(minter);
        vm.expectRevert(abi.encodeWithSelector(RwaUsd.AddressIsBlocklisted.selector, alice));
        token.mint(alice, 100e18);
    }

    /**
     * @notice Burning from a blocklisted address reverts
     */
    function test_burn_RevertsWhenAccountIsBlocklisted() public {
        vm.prank(minter);
        token.mint(alice, 100e18);

        vm.prank(alice);
        token.approve(burner, 100e18);

        vm.prank(admin);
        token.addToBlocklist(alice);

        vm.prank(burner);
        vm.expectRevert(abi.encodeWithSelector(RwaUsd.AddressIsBlocklisted.selector, alice));
        token.burn(alice, 100e18);
    }

    /**
     * @notice Transfer succeeds after removing address from blocklist
     */
    function test_transfer_SuccessAfterRemovingFromBlocklist() public {
        vm.prank(minter);
        token.mint(alice, 100e18);

        vm.startPrank(admin);
        token.addToBlocklist(alice);
        token.removeFromBlocklist(alice);
        vm.stopPrank();

        vm.prank(alice);
        token.transfer(bob, 100e18);
        assertEq(token.balanceOf(bob), 100e18);
    }

    // ================================================================
    // │                       Upgrade                                │
    // ================================================================

    /**
     * @notice Admin can upgrade the proxy to a new implementation
     */
    function test_upgrade_SuccessWhenCalledByAdmin() public {
        vm.startPrank(admin);
    
        Upgrades.upgradeProxy(address(token), "MockRwaUsdV2.sol", "");
        vm.stopPrank();

        string memory response = MockRwaUsdV2(address(token)).newMethod();
        assertEq(response, "new method");
    }

    /**
     * @notice New implementation can set and read new storage variables
     */
    function test_upgrade_NewStorageVariableWorks() public {
        vm.startPrank(admin);
        Upgrades.upgradeProxy(address(token), "MockRwaUsdV2.sol", "");

        MockRwaUsdV2 tokenV2 = MockRwaUsdV2(address(token));
        tokenV2.setNewVariable(42);
        assertEq(tokenV2.newVariable(), 42);
    }

    /**
     * @notice Existing state (blocklist, pause) is preserved across upgrades
     */
    function test_upgrade_ExistingStatePreserved() public {
        vm.startPrank(admin);
        token.pauseTransfers();
        token.addToBlocklist(alice);
        vm.stopPrank();

        vm.startPrank(admin);

        Upgrades.upgradeProxy(address(token), "MockRwaUsdV2.sol", "");

        assertTrue(token.transfersPaused());
        assertTrue(token.isBlocklisted(alice));
    }

    /**
     * @notice Non-admin cannot upgrade the proxy
     */
    function test_upgrade_RevertsWhenCalledByNonAdmin() public {
        address newImpl = address(new MockRwaUsdV2());
        vm.prank(alice);
        vm.expectRevert();
        token.upgradeToAndCall(newImpl, "");
    }

    /**
     * @notice Token balances are preserved across upgrades
     */
    function test_upgrade_BalancesPreserved() public {
        vm.prank(minter);
        token.mint(alice, 100e18);

        vm.startPrank(admin);
        Upgrades.upgradeProxy(address(token), "MockRwaUsdV2.sol", "");

        assertEq(token.balanceOf(alice), 100e18);
    }
}
