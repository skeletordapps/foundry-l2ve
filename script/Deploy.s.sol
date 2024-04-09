// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {L2VE} from "../src/L2VE.sol";

contract Deploy is Script {
    function run() external returns (L2VE l2ve) {
        string memory name = "L2VE";
        string memory symbol = "L2VE";
        uint256 supply = 1_000_000_000 ether;

        uint256 privateKey = vm.envUint("NEW_PRIVATE_KEY");

        vm.startBroadcast(privateKey);
        l2ve = new L2VE(name, symbol, supply);
        vm.stopBroadcast();

        return l2ve;
    }
}
