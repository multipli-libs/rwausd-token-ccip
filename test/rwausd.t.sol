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

    /// @dev The ERC-7201 storage slot for BurnMintERC20Storage:
    ///      keccak256(abi.encode(uint256(keccak256("burnminterc20.storage.BurnMintERC20Storage")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 internal constant BURN_MINT_ERC20_STORAGE_SLOT =
        0x48733b579cb8ee0f498a5cd23cb2e466f92e044f7077bd86ce4fff1c306c0100;

    function setUp() public {
        vm.startPrank(deployer);
        bytes memory data = abi.encodeWithSelector(RwaUsd.initialize.selector, admin);

        address proxy = Upgrades.deployUUPSProxy("RwaUsd.sol", data);

        token = RwaUsd(address(proxy));
        vm.stopPrank();

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

    function test_upgrade_NewStorageVariableWorks() public {
        vm.startPrank(admin);
        Upgrades.upgradeProxy(address(token), "MockRwaUsdV2.sol", "");

        MockRwaUsdV2 tokenV2 = MockRwaUsdV2(address(token));
        tokenV2.setNewVariable(42);
        assertEq(tokenV2.newVariable(), 42);
    }

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

    // ================================================================
    // │                  Namespaced Storage Integrity                │
    // ================================================================

    /// @dev Reads raw slot values in a window around the BurnMintERC20Storage
    ///      namespace. Used to snapshot state before/after an upgrade so we
    ///      can assert no slot was silently overwritten (collision guard).
    ///
    ///      BurnMintERC20Storage layout (ERC-7201, starting at BURN_MINT_ERC20_STORAGE_SLOT):
    ///        slot+0  → uint8 decimals  (packed in low byte)
    ///        slot+1  → uint256 maxSupply
    ///        slot+2  → address ccipAdmin
    function _readNamespaceWindow(address proxy)
        internal
        view
        returns (bytes32 slotMinus1, bytes32 slot0, bytes32 slot1, bytes32 slot2, bytes32 slot3)
    {
        slotMinus1 = vm.load(proxy, bytes32(uint256(BURN_MINT_ERC20_STORAGE_SLOT) - 1));
        slot0 = vm.load(proxy, BURN_MINT_ERC20_STORAGE_SLOT);
        slot1 = vm.load(proxy, bytes32(uint256(BURN_MINT_ERC20_STORAGE_SLOT) + 1));
        slot2 = vm.load(proxy, bytes32(uint256(BURN_MINT_ERC20_STORAGE_SLOT) + 2));
        slot3 = vm.load(proxy, bytes32(uint256(BURN_MINT_ERC20_STORAGE_SLOT) + 3));
    }

    /**
     * @notice After upgrade, namespace slot+0 must decode to exactly 18 —
     *         checked both from the raw slot byte and via decimals().
     */
    function test_upgrade_storage_DecimalsUnchanged() public {
        vm.startPrank(admin);
        Upgrades.upgradeProxy(address(token), "MockRwaUsdV2.sol", "");
        vm.stopPrank();

        bytes32 rawSlot = vm.load(address(token), BURN_MINT_ERC20_STORAGE_SLOT);

        // uint8 decimals is packed in the low byte of slot+0
        uint8 rawDecimals = uint8(uint256(rawSlot));
        assertEq(rawDecimals, 18, "Storage slot+0 raw decimals != 18 after upgrade");
        assertEq(token.decimals(), 18, "decimals() != 18 after upgrade");
    }

    /**
     * @notice After upgrade, namespace slot+1 must decode to the expected
     *         maxSupply value — checked both from the raw slot and via maxSupply().
     */
    function test_upgrade_storage_MaxSupplyUnchanged() public {
        uint256 expectedMaxSupply = token.maxSupply();

        vm.startPrank(admin);
        Upgrades.upgradeProxy(address(token), "MockRwaUsdV2.sol", "");
        vm.stopPrank();

        bytes32 rawSlot = vm.load(address(token), bytes32(uint256(BURN_MINT_ERC20_STORAGE_SLOT) + 1));

        // Full uint256 occupies slot+1
        uint256 rawMaxSupply = uint256(rawSlot);
        assertEq(rawMaxSupply, expectedMaxSupply, "Storage slot+1 raw maxSupply != expected after upgrade");
        assertEq(token.maxSupply(), expectedMaxSupply, "maxSupply() != expected after upgrade");
        assertEq(
            MockRwaUsdV2(address(token)).maxSupply(), expectedMaxSupply, "V2 maxSupply() != expected after upgrade"
        );
    }

    /**
     * @notice After upgrade, namespace slot+2 must decode to exactly the admin
     *         address — checked both from the raw slot bytes and via getCCIPAdmin().
     */
    function test_upgrade_storage_CcipAdminSlotUnchanged() public {
        vm.startPrank(admin);
        Upgrades.upgradeProxy(address(token), "MockRwaUsdV2.sol", "");
        vm.stopPrank();

        bytes32 rawSlot = vm.load(address(token), bytes32(uint256(BURN_MINT_ERC20_STORAGE_SLOT) + 2));

        // address is stored in the low 20 bytes of slot+2
        address rawCcipAdmin = address(uint160(uint256(rawSlot)));
        assertEq(rawCcipAdmin, admin, "Storage slot+2 raw ccipAdmin != admin after upgrade");
        assertEq(token.getCCIPAdmin(), admin, "getCCIPAdmin() != admin after upgrade");
    }

    /**
     * @notice Captures a 5-slot window around the BurnMintERC20Storage
     *         namespace before and after upgrade. Every slot in the window
     *         must remain byte-identical — any difference indicates a storage
     *         collision introduced by the new implementation.
     */
    function test_upgrade_storage_NoSlotCollision() public {
        (bytes32 pre_m1, bytes32 pre_0, bytes32 pre_1, bytes32 pre_2, bytes32 pre_3) =
            _readNamespaceWindow(address(token));

        vm.startPrank(admin);
        Upgrades.upgradeProxy(address(token), "MockRwaUsdV2.sol", "");
        vm.stopPrank();

        (bytes32 post_m1, bytes32 post_0, bytes32 post_1, bytes32 post_2, bytes32 post_3) =
            _readNamespaceWindow(address(token));

        assertEq(pre_m1, post_m1, "Slot collision: slot before namespace was overwritten");
        assertEq(pre_0, post_0, "Slot collision: namespace slot+0 (decimals) was overwritten");
        assertEq(pre_1, post_1, "Slot collision: namespace slot+1 (maxSupply) was overwritten");
        assertEq(pre_2, post_2, "Slot collision: namespace slot+2 (ccipAdmin) was overwritten");
        assertEq(pre_3, post_3, "Slot collision: namespace slot+3 (reserved/future) was overwritten");
    }

    /**
     * @notice Mints to two accounts before upgrade, then asserts that
     *         totalSupply and both individual balances survive intact.
     *         ERC20 balances live in their own ERC-7201 namespace
     *         (separate from BurnMintERC20Storage) so this exercises a
     *         different region of proxy storage.
     */
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

    /**
     * @notice After upgrading to V2, writing to V2's new storage variable must
     *         not overwrite any slot in the inherited BurnMintERC20Storage namespace.
     *         Each field is decoded and asserted against its concrete expected value.
     */
    function test_upgrade_storage_V2StorageDoesNotCollideWithNamespace() public {
        vm.startPrank(admin);
        Upgrades.upgradeProxy(address(token), "MockRwaUsdV2.sol", "");
        vm.stopPrank();

        uint256 expectedMaxSupply = MockRwaUsdV2(address(token)).maxSupply();

        // Write to V2-specific storage
        MockRwaUsdV2(address(token)).setNewVariable(12345);

        // Decode each namespace field from its raw slot and assert the concrete expected value
        uint8 rawDecimals = uint8(uint256(vm.load(address(token), BURN_MINT_ERC20_STORAGE_SLOT)));
        uint256 rawMaxSupply = uint256(vm.load(address(token), bytes32(uint256(BURN_MINT_ERC20_STORAGE_SLOT) + 1)));
        address rawCcipAdmin =
            address(uint160(uint256(vm.load(address(token), bytes32(uint256(BURN_MINT_ERC20_STORAGE_SLOT) + 2)))));

        assertEq(rawDecimals, 18, "V2 write collided with namespace slot+0: decimals != 18");
        assertEq(rawMaxSupply, expectedMaxSupply, "V2 write collided with namespace slot+1: maxSupply changed");
        assertEq(rawCcipAdmin, admin, "V2 write collided with namespace slot+2: ccipAdmin != admin");

        // And the V2 value is stored correctly at its own location
        assertEq(MockRwaUsdV2(address(token)).newVariable(), 12345, "V2 newVariable not stored correctly");
    }

    /**
     * @notice Verifies that the BURN_MINT_ERC20_STORAGE_SLOT constant in
     *         this test file matches the one computed from the canonical
     *         ERC-7201 formula used in the contract. A mismatch would mean
     *         the tests above are inspecting the wrong slots entirely.
     */
    function test_upgrade_storage_SlotConstantMatchesERC7201Formula() public pure {
        bytes32 computed = keccak256(abi.encode(uint256(keccak256("burnminterc20.storage.BurnMintERC20Storage")) - 1))
            & ~bytes32(uint256(0xff));

        assertEq(
            computed,
            BURN_MINT_ERC20_STORAGE_SLOT,
            "BURN_MINT_ERC20_STORAGE_SLOT constant does not match ERC-7201 formula"
        );
    }
}
