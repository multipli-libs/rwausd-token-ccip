// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {rwaUSD} from "src/token/RWAUSD.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {
    IAccessControlDefaultAdminRules
} from "@openzeppelin/contracts/access/extensions/IAccessControlDefaultAdminRules.sol";
import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";

import {RwaUsdBaseTest} from "./BaseTest.t.sol";

contract TestInitialize is RwaUsdBaseTest {
    function test_Initialize_NameSetCorrectly() public view {
        assertEq(s_rwausd.name(), "Real World Asset USD");
    }

    function test_Initialize_SymbolSetCorrectly() public view {
        assertEq(s_rwausd.symbol(), "rwaUSD");
    }

    function test_Initialize_DecimalsSetCorrectly() public view {
        assertEq(s_rwausd.decimals(), 18);
    }

    function test_Initialize_MaxSupplySetCorrectly() public view {
        assertEq(s_rwausd.maxSupply(), 0);
    }

    function test_Initialize_TotalSupplyIsZero() public view {
        assertEq(s_rwausd.totalSupply(), 0);
    }

    function test_Initialize_AdminSetCorrectly() public view {
        assertTrue(s_rwausd.hasRole(s_rwausd.DEFAULT_ADMIN_ROLE(), s_admin));
    }

    function test_Initialize_CcipAdminSetCorrectly() public view {
        assertEq(s_rwausd.getCCIPAdmin(), s_admin);
    }

    function test_Initialize_DefaultAdminDelaySetCorrectly() public view {
        assertEq(s_rwausd.defaultAdminDelay(), ADMIN_DELAY);
    }

    function test_Initialize_MinterRoleSetCorrectly() public view {
        assertTrue(s_rwausd.hasRole(s_rwausd.MINTER_ROLE(), s_minter));
    }

    function test_Initialize_BurnerRoleSetCorrectly() public view {
        assertTrue(s_rwausd.hasRole(s_rwausd.BURNER_ROLE(), s_burner));
    }

    function test_Initialize_PauserRoleSetCorrectly() public view {
        assertTrue(s_rwausd.hasRole(s_rwausd.PAUSER_ROLE(), s_pauser));
    }

    function test_Initialize_UpgraderRoleSetCorrectly() public view {
        assertTrue(s_rwausd.hasRole(s_rwausd.UPGRADER_ROLE(), s_admin));
    }

    function test_Initialize_DeployerRoleRevoked() public view {
        assertFalse(s_rwausd.hasRole(s_rwausd.DEFAULT_ADMIN_ROLE(), s_deployer));
    }

    function test_Initialize_WithPreMint() public {
        address implementation = address(new rwaUSD());
        ERC1967Proxy proxy = new ERC1967Proxy(
            implementation,
            abi.encodeCall(rwaUSD.initialize, ("Real World Asset USD", "rwaUSD", 18, 1000e18, 100e18, s_admin, s_admin))
        );
        rwaUSD newToken = rwaUSD(address(proxy));

        assertEq(newToken.totalSupply(), 100e18);
        assertEq(newToken.balanceOf(s_admin), 100e18);
    }

    function test_Initialize_RevertWhen_CalledAgain() public {
        vm.expectRevert(Initializable.InvalidInitialization.selector);
        s_rwausd.initialize("Real World Asset USD", "rwaUSD", 18, 0, 0, s_alice, s_alice);
    }

    function test_Initialize_RevertWhen_AdminIsZeroAddress() public {
        address implementation = address(new rwaUSD());

        vm.expectRevert("Admin address is 0");

        new ERC1967Proxy(
            implementation,
            abi.encodeCall(rwaUSD.initialize, ("Real World Asset USD", "rwaUSD", 18, 0, 0, address(0), s_alice))
        );
    }

    function test_Initialize_RevertWhen_UpgraderIsZeroAddress() public {
        address implementation = address(new rwaUSD());

        vm.expectRevert("Upgrader address is 0");

        new ERC1967Proxy(
            implementation,
            abi.encodeCall(rwaUSD.initialize, ("Real World Asset USD", "rwaUSD", 18, 0, 0, s_alice, address(0)))
        );
    }

    function test_Initialize_RevertWhen_PreMintExceedsMaxSupply() public {
        address implementation = address(new rwaUSD());

        vm.expectRevert(abi.encodeWithSelector(rwaUSD.RwaUsd__MaxSupplyExceeded.selector, 200e18));

        new ERC1967Proxy(
            implementation,
            abi.encodeCall(rwaUSD.initialize, ("Real World Asset USD", "rwaUSD", 18, 100e18, 200e18, s_admin, s_admin))
        );
    }
}
