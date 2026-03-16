// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {HelperUtils} from "./utils/HelperUtils.s.sol";
import {ChainNameResolver} from "./utils/ChainNameResolver.s.sol";
import {RwaUsd} from "src/token/RwaUsd.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";

contract DeployToken is Script {
    function run() external {
        ChainNameResolver resolver = new ChainNameResolver();
        string memory chainName = resolver.getChainNameSafe(block.chainid);

        string memory root = vm.projectRoot();
        string memory configPath = vm.envOr("CONFIG_PATH", string.concat(root, "/script/config.json"));

        address admin = HelperUtils.getAddressFromJson(vm, configPath, ".rwaUSDToken.ccipAdminAddress");

        vm.startBroadcast();

        bytes memory data = abi.encodeWithSelector(RwaUsd.initialize.selector, admin);
        address proxy = Upgrades.deployUUPSProxy("RwaUsd.sol", data);

        console.log("Deployed rwausd proxy at:", proxy);
        console.log("Admin:", admin);

        vm.stopBroadcast();

        string memory jsonObj = "internal_key";
        string memory key = string(abi.encodePacked("deployedToken_", chainName));
        string memory finalJson = vm.serializeAddress(jsonObj, key, proxy);

        string memory fileName = string(abi.encodePacked("./script/output/deployedToken_", chainName, ".json"));
        console.log("Writing deployed token address to file:", fileName);
        vm.writeJson(finalJson, fileName);
    }
}
