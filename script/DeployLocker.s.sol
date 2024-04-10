// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {L2VELocker} from "../src/L2VELocker.sol";

contract DeployLocker is Script {
    function run() external returns (L2VELocker l2veLocker) {
        uint256 privateKey = vm.envUint("NEW_PRIVATE_KEY");

        vm.startBroadcast(privateKey);
        l2veLocker = new L2VELocker();
        vm.stopBroadcast();

        return l2veLocker;
    }

    function testMock() public {}
}
