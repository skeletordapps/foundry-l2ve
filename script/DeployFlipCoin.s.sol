// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import {Script} from "forge-std/Script.sol";
import {L2VEFlipCoin} from "../src/L2VEFlipCoin.sol";

contract DeployFlipCoin is Script {
    function run() external returns (L2VEFlipCoin l2veFlipCoin) {
        uint256 privateKey = vm.envUint("NEW_PRIVATE_KEY");

        vm.startBroadcast(privateKey);
        l2veFlipCoin = new L2VEFlipCoin();
        vm.stopBroadcast();

        return l2veFlipCoin;
    }
}
