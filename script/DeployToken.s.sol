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



// ##### mainnet
// ✅  [Success] Hash: 0xbe1e88a2ecb573a282aca5a11d1dc335b9a40d79d1e997ec4edf69d373ada3f8
// Contract Address: 0x8Fcd23142047A3073ed332a0Ed07d1e8D2BD5177
// Block: 24792046
// Paid: 0.000054606198288866 ETH (326102 gas * 0.167451283 gwei)
// 
// 
// ##### mainnet
// ✅  [Success] Hash: 0x01dfef865f4ac07ab37b39465ac836309d556b09d71dce3c8622c3d0ee3990a3
// Contract Address: 0xFfC4232F122377dD89E4b04A2c277fC9d6780d2C
// Block: 24792046
// Paid: 0.000512210198968663 ETH (3058861 gas * 0.167451283 gwei)
// 
// ✅ Sequence #1 on mainnet | Total Paid: 0.000566816397257529 ETH (3384963 gas * avg 0.167451283 gwei)
// 
// 
// ==========================
// 
// ONCHAIN EXECUTION COMPLETE & SUCCESSFUL.
// 
// Transactions saved to: /Users/bhaveshpraveen/multipli-projects/deployment-mainnet-repos/rwaUSD/rwausd-token-ccip/broadcast/DeployToken.s.sol/1/run-latest.json
// 
// Sensitive values saved to: /Users/bhaveshpraveen/multipli-projects/deployment-mainnet-repos/rwaUSD/rwausd-token-ccip/cache/DeployToken.s.sol/1/run-latest.json
