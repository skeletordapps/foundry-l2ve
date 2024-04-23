// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {L2VENFTPublic} from "../src/L2VENFTPublic.sol";

contract DeployNFTPublic is Script {
    function run() external returns (L2VENFTPublic nft) {
        uint256 privateKey = vm.envUint("NEW_PRIVATE_KEY");
        address l2veAddress;
        address l2veNftPhase1Address;

        vm.startBroadcast(privateKey);

        l2veAddress = 0xA19328fb05ce6FD204D16c2a2A98F7CF434c12F4;
        l2veNftPhase1Address = 0x43b63FD20A6ec01fC84645094852840D569bE9ED;

        nft = new L2VENFTPublic(l2veAddress, l2veNftPhase1Address);
        vm.stopBroadcast();

        return nft;
    }

    function testMock() public {}
}
