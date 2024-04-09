// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {L2VEMultiSender} from "../src/L2VEMultiSender.sol";

contract DeployMultiSender is Script {
    function run() external returns (L2VEMultiSender l2veMultiSender) {
        uint256 privateKey = vm.envUint("NEW_PRIVATE_KEY");

        vm.startBroadcast(privateKey);
        l2veMultiSender = new L2VEMultiSender();
        vm.stopBroadcast();

        return l2veMultiSender;
    }
}
