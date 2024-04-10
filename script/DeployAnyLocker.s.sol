// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {L2VEAnyLocker} from "../src/L2VEAnyLocker.sol";
import {L2VEMock} from "../src/mocks/L2VEMock.sol";

contract DeployAnyLocker is Script {
    function run() external returns (L2VEAnyLocker l2veAnyLocker) {
        uint256 privateKey = vm.envUint("NEW_PRIVATE_KEY");

        vm.startBroadcast(privateKey);

        if (block.chainid == 31337) {
            new L2VEMock("TOKEN1", "TOKEN1");
            new L2VEMock("TOKEN2", "TOKEN2");
            new L2VEMock("TOKEN3", "TOKEN3");
        }

        l2veAnyLocker = new L2VEAnyLocker();

        vm.stopBroadcast();

        return l2veAnyLocker;
    }

    function testMock() public {}
}
