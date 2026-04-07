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

    function test_sanityCheckForVariables() public {
        ClaimAdminAndAcceptAdmin.ClaimAdminConfig memory scriptConfig = script.loadConfig();

        assertEq(scriptConfig.registryModuleOwnerCustom, 0x4855174E9479E211337832E109E7721d43A4CA64, "registryModuleOwnerCustom sanity check failed");
        assertEq(scriptConfig.tokenAdminRegistry, 0xb22764f98dD05c789929716D677382Df22C05Cb6, "tokenAdminRegistry sanity check failed");
        assertEq(scriptConfig.tokenAdmin, 0x194Ebc1B9B382ef0E6998cAAcE59aF843cf53b99, "tokenAdmin sanity check failed");
        assertEq(scriptConfig.tokenAddress, 0x8Fcd23142047A3073ed332a0Ed07d1e8D2BD5177, "tokenAddress sanity check failed");

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
