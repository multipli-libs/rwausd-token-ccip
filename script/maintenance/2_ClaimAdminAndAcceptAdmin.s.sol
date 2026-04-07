// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {HelperUtils} from "../utils/HelperUtils.s.sol";
import {HelperConfig} from "../HelperConfig.s.sol";
import {ChainNameResolver} from "../utils/ChainNameResolver.s.sol";
import {
    RegistryModuleOwnerCustom
} from "@chainlink/contracts-ccip/contracts/tokenAdminRegistry/RegistryModuleOwnerCustom.sol";
import {TokenAdminRegistry} from "@chainlink/contracts-ccip/contracts/tokenAdminRegistry/TokenAdminRegistry.sol";
import {rwaUSD} from "src/token/RWAUSD.sol";

contract ClaimAdminAndAcceptAdmin is Script {
    address internal constant TOKEN_ADMIN = 0x194Ebc1B9B382ef0E6998cAAcE59aF843cf53b99; // Multipli Safe Wallet

    struct ClaimAdminConfig {
        address tokenAddress;
        address registryModuleOwnerCustom;
        address tokenAdminRegistry;
        address tokenAdmin;
    }

    function run() external {
        _runInternal(false, address(0));
    }

    function runWithPrankedUser(address user) external {
        _runInternal(true, user);
    }

    function _runInternal(bool usePrank, address user) internal {
        ClaimAdminConfig memory config = loadConfig();
        _validateConfig(config);

        bytes memory callData1 = _buildClaimAdminCalldata(config.tokenAddress);
        bytes memory callData2 = _buildAcceptAdminRoleCalldata(config.tokenAddress);

        _logSafeTransaction(config.registryModuleOwnerCustom, callData1, config.tokenAdminRegistry, callData2);

        if (usePrank) {
            vm.startPrank(user);
            _execute(config.registryModuleOwnerCustom, callData1, config.tokenAdminRegistry, callData2);
            vm.stopPrank();
        }
    }

    function loadConfig() public returns (ClaimAdminConfig memory config) {
        config.tokenAdmin = TOKEN_ADMIN;
        config.tokenAddress = _loadTokenAddress();
        config.registryModuleOwnerCustom = _loadRegistryModuleOwnerCustom();
        config.tokenAdminRegistry = _loadTokenAdminRegistry();
    }

    function _loadTokenAddress() internal returns (address tokenAddress) {
        ChainNameResolver resolver = new ChainNameResolver();
        string memory chainName = resolver.getChainNameSafe(block.chainid);

        string memory root = vm.projectRoot();
        string memory deployedTokenPath = string.concat(root, "/script/output/deployedToken_", chainName, ".json");

        tokenAddress =
            HelperUtils.getAddressFromJson(vm, deployedTokenPath, string.concat(".deployedToken_", chainName));
    }

    function _loadRegistryModuleOwnerCustom() internal returns (address registryModuleOwnerCustom) {
        HelperConfig helperConfig = new HelperConfig();
        (,,,, registryModuleOwnerCustom,,,) = helperConfig.activeNetworkConfig();
    }

    function _loadTokenAdminRegistry() internal returns (address tokenAdminRegistry) {
        HelperConfig helperConfig = new HelperConfig();
        (,,, tokenAdminRegistry,,,,) = helperConfig.activeNetworkConfig();
    }

    function _validateConfig(ClaimAdminConfig memory config) internal view {
        require(config.tokenAddress != address(0), "Invalid token address");
        require(
            config.registryModuleOwnerCustom != address(0),
            "Registry module owner custom is not defined for this network"
        );

        require(config.tokenAdminRegistry != address(0), "Token Admin Registry is not defined for this network");

        address currentCCIPAdmin = rwaUSD(config.tokenAddress).getCCIPAdmin();
        console.log("Current token admin:", currentCCIPAdmin);

        require(currentCCIPAdmin == config.tokenAdmin, "CCIP admin of token doesn't match the token admin address");
    }

    function _buildClaimAdminCalldata(address tokenAddress) internal pure returns (bytes memory) {
        return abi.encodeWithSelector(RegistryModuleOwnerCustom.registerAdminViaGetCCIPAdmin.selector, tokenAddress);
    }

    function _buildAcceptAdminRoleCalldata(address tokenAddress) internal pure returns (bytes memory) {
        return abi.encodeWithSelector(TokenAdminRegistry.acceptAdminRole.selector, tokenAddress);
    }

    function _logSafeTransaction(
        address registryModuleOwnerCustom,
        bytes memory cd1,
        address tokenAdminRegistry,
        bytes memory cd2
    ) internal view {
        console.log("=== Safe Wallet Transaction 1 ===");
        console.log("To (registryModuleOwnerCustom):", registryModuleOwnerCustom);
        console.log("Value: 0");
        console.log("Calldata:");
        console.logBytes(cd1);
        console.log("===============================");

        console.log("=== Safe Wallet Transaction 2 ===");
        console.log("To (tokenAdminRegistry):", tokenAdminRegistry);
        console.log("Value: 0");
        console.log("Calldata:");
        console.logBytes(cd2);
        console.log("===============================");
    }

    function _execute(
        address registryModuleOwnerCustom,
        bytes memory callData1,
        address tokenAdminRegistry,
        bytes memory callData2
    ) internal {
        (bool success,) = registryModuleOwnerCustom.call(callData1);
        require(success, "error executing calldata1");

        (success,) = tokenAdminRegistry.call(callData2);
        require(success, "error executing calldata2");
    }
}
