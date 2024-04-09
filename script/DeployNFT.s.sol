// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {L2VENFT} from "../src/L2VENFT.sol";

contract DeployNFT is Script {
    function run() external returns (L2VENFT l2veNFT) {
        uint256 privateKey = vm.envUint("NEW_PRIVATE_KEY");

        vm.startBroadcast(privateKey);
        l2veNFT = new L2VENFT();
        vm.stopBroadcast();

        return l2veNFT;
    }
}
