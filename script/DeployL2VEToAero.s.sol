// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {L2VEToAero} from "../src/L2VEToAero.sol";

contract DeployL2VEToAero is Script {
    function run() external returns (L2VEToAero l2veToAero) {
        uint256 privateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(privateKey);

        l2veToAero = new L2VEToAero();

        vm.stopBroadcast();

        return l2veToAero;
    }

    function testMock() public {}
}
