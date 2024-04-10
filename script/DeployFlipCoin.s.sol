// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {console2} from "forge-std/Test.sol";
import {Script} from "forge-std/Script.sol";
import {L2VEFlipCoin} from "../src/L2VEFlipCoin.sol";
import {L2VEMock} from "../src/mocks/L2VEMock.sol";

contract DeployFlipCoin is Script {
    function run() external returns (L2VEFlipCoin l2veFlipCoin) {
        uint256 privateKey;
        address l2veAddress;
        address multisig;

        privateKey = block.chainid == 31337 ? vm.envUint("MNEMONIC") : vm.envUint("NEW_PRIVATE_KEY");
        vm.startBroadcast(privateKey);

        if (block.chainid == 31337) {
            L2VEMock l2veMock = new L2VEMock("L2VE", "L2VE");
            l2veAddress = address(l2veMock);
            multisig = msg.sender;
        } else {
            l2veAddress = 0xA19328fb05ce6FD204D16c2a2A98F7CF434c12F4;
            multisig = 0xC2a96B13a975c656f60f401a5F72851af4717D4A;
        }

        l2veFlipCoin = new L2VEFlipCoin(l2veAddress, multisig);
        vm.stopBroadcast();

        return l2veFlipCoin;
    }

    function testMock() public {}
}
