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
}