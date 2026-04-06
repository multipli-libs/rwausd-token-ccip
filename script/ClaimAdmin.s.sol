// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {HelperUtils} from "./utils/HelperUtils.s.sol"; // Utility functions for JSON parsing and chain info
import {HelperConfig} from "./HelperConfig.s.sol"; // Network configuration helper
import {ChainNameResolver} from "./utils/ChainNameResolver.s.sol"; // Chain name resolution utility
import {
    RegistryModuleOwnerCustom
} from "@chainlink/contracts-ccip/contracts/tokenAdminRegistry/RegistryModuleOwnerCustom.sol";
import {rwaUSD} from "src/token/RWAUSD.sol";

contract ClaimAdmin is Script {
    address tokenAdmin = 0x194Ebc1B9B382ef0E6998cAAcE59aF843cf53b99; //Multipli Safe Wallet

    function run() external {
        ChainNameResolver resolver = new ChainNameResolver();
        // Get the chain name based on the current chain ID
        string memory chainName = resolver.getChainNameSafe(block.chainid);

        // Define paths to the necessary JSON files
        string memory root = vm.projectRoot();
        string memory deployedTokenPath = string.concat(root, "/script/output/deployedToken_", chainName, ".json");
        string memory configPath = vm.envOr("CONFIG_PATH", string.concat(root, "/script/mainnet.config.json"));

        // Extract values from the JSON files
        address tokenAddress =
            HelperUtils.getAddressFromJson(vm, deployedTokenPath, string.concat(".deployedToken_", chainName));

        // Fetch the network configuration
        HelperConfig helperConfig = new HelperConfig();
        (,,,, address registryModuleOwnerCustom,,,) = helperConfig.activeNetworkConfig();

        require(tokenAddress != address(0), "Invalid token address");
        require(registryModuleOwnerCustom != address(0), "Registry module owner custom is not defined for this network");

        logClaimAdminCalldata(tokenAddress, tokenAdmin, registryModuleOwnerCustom);
    }

    function logClaimAdminCalldata(address tokenAddress, address tokenAdmin, address registryModuleOwnerCustom)
        internal
        view
    {
        // Instantiate the token contract with CCIP admin functionality
        rwaUSD tokenContract = rwaUSD(tokenAddress);

        // Get the current CCIP admin of the token
        address tokenContractCCIPAdmin = tokenContract.getCCIPAdmin();
        console.log("Current token admin:", tokenContractCCIPAdmin);

        // Ensure the CCIP admin matches the expected token admin address
        require(tokenContractCCIPAdmin == tokenAdmin, "CCIP admin of token doesn't match the token admin address.");

        // Encode the calldata for registerAdminViaGetCCIPAdmin(address)
        bytes memory callData =
            abi.encodeWithSelector(RegistryModuleOwnerCustom.registerAdminViaGetCCIPAdmin.selector, tokenAddress);

        console.log("=== Safe Wallet Transaction ===");
        console.log("To (registryModuleOwnerCustom):", registryModuleOwnerCustom);
        console.log("Value: 0");
        console.log("Calldata:");
        console.logBytes(callData);
        console.log("===============================");
    }
}
