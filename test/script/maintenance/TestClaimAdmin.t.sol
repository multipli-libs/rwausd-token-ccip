// SPDX-License-Identifier: MIT

pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {ClaimAdminAndAcceptAdmin} from "../../../script/maintenance/2_ClaimAdminAndAcceptAdmin.s.sol";
import {HelperUtils} from "../../../script/utils/HelperUtils.s.sol";
import {TokenAdminRegistry} from "@chainlink/contracts-ccip/contracts/tokenAdminRegistry/TokenAdminRegistry.sol";

contract TestClaimAdminAndAcceptAdmin is Test {
    uint256 BLOCK_NUMBER = 24_793_691 + 1;
    ClaimAdminAndAcceptAdmin script;

    function setUp() public {
        string memory rpcUrl = vm.envString("RPC_URL_ETHEREUM");
        vm.createSelectFork(rpcUrl, BLOCK_NUMBER);

        script = new ClaimAdminAndAcceptAdmin();
    }

    function _runScript(address user) internal {
        script.runWithPrankedUser(user);
    }

    function test__beforeRunningScript() public {
        ClaimAdminAndAcceptAdmin.ClaimAdminConfig memory scriptConfig = script.loadConfig();

        TokenAdminRegistry.TokenConfig memory config =
            TokenAdminRegistry(scriptConfig.tokenAdminRegistry).getTokenConfig(scriptConfig.tokenAddress);
        assertEq(config.administrator, address(0), "Admin has been set");
    }

    function test__afterRunningScript() public {
        ClaimAdminAndAcceptAdmin.ClaimAdminConfig memory scriptConfig = script.loadConfig();

        _runScript(scriptConfig.tokenAdmin);

        TokenAdminRegistry.TokenConfig memory tokenRegistryConfig =
            TokenAdminRegistry(scriptConfig.tokenAdminRegistry).getTokenConfig(scriptConfig.tokenAddress);
        assertEq(tokenRegistryConfig.administrator, scriptConfig.tokenAdmin, "Admin has not been set");
    }
}
