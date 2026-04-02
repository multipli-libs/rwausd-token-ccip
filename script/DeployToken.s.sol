// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {HelperUtils} from "./utils/HelperUtils.s.sol";
import {ChainNameResolver} from "./utils/ChainNameResolver.s.sol";
import {rwaUSD} from "src/token/RWAUSD.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";

contract DeployToken is Script {
    function run() external {
        ChainNameResolver resolver = new ChainNameResolver();
        string memory chainName = resolver.getChainNameSafe(block.chainid);

        string memory root = vm.projectRoot();
        string memory configPath = vm.envOr("CONFIG_PATH", string.concat(root, "/script/mainnet.config.json"));

        address admin = HelperUtils.getAddressFromJson(vm, configPath, ".rwaUSDToken.ccipAdminAddress");

        address deployer = msg.sender;
        
        require(deployer == admin, string(abi.encodePacked(
            "Deployer mismatch: expected ", vm.toString(admin),
            " but got ", vm.toString(deployer)
        )));

        vm.startBroadcast();

        bytes memory data = abi.encodeCall(
            rwaUSD.initialize,
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
        address proxy = Upgrades.deployUUPSProxy("RWAUSD.sol:rwaUSD", data);

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
