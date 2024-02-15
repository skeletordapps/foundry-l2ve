// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import {Script, console2} from "forge-std/Script.sol";
import {Meme} from "../src/Meme.sol";

contract DeployMeme is Script {
    function run() external returns (Meme meme) {
        string memory name = "LOVE TITS";
        string memory symbol = "LTS";
        address routerAddress = vm.envAddress("BASE_SWAP_ROUTER");
        address wethAddres = vm.envAddress("BASE_WETH_ADDRESS");

        vm.startBroadcast();
        meme = new Meme(name, symbol, routerAddress, wethAddres);
        vm.stopBroadcast();

        return meme;
    }
}
