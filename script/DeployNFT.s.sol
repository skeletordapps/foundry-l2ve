// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {L2VENFT} from "../src/L2VENFT.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {L2VEMock} from "../src/mocks/L2VEMock.sol";

contract DeployNFT is Script {
    function run(bool _testing) external returns (L2VENFT nft) {
        uint256 privateKey = vm.envUint("NEW_PRIVATE_KEY");
        address l2veAddress;

        vm.startBroadcast(privateKey);

        if (block.chainid == 31337) {
            L2VEMock l2veMock = new L2VEMock("L2VEM", "L2VEM");
            l2veAddress = address(l2veMock);
        } else {
            l2veAddress = 0xA19328fb05ce6FD204D16c2a2A98F7CF434c12F4;
        }

        nft = new L2VENFT(l2veAddress);

        if (!_testing) {
            address[] memory permittedTokens = setPermittedTokens();
            nft.addPermittedTokens(permittedTokens);
        }

        vm.stopBroadcast();

        return nft;
    }

    function setPermittedTokens() internal returns (address[] memory) {
        address degen;
        address normie;
        address brett;
        address doginme;
        address tybg;

        if (block.chainid == 31337) {
            L2VEMock degenMock = new L2VEMock("DEGEN", "DEGEN");
            L2VEMock normieMock = new L2VEMock("NORMIE", "NORMIE");
            L2VEMock brettMock = new L2VEMock("BRETT", "BRETT");
            L2VEMock doginmeMock = new L2VEMock("DOGINME", "DOGINME");
            L2VEMock tybgMock = new L2VEMock("TYBG", "TYBG");

            degen = address(degenMock);
            normie = address(normieMock);
            brett = address(brettMock);
            doginme = address(doginmeMock);
            tybg = address(tybgMock);
        } else {
            degen = 0x4ed4E862860beD51a9570b96d89aF5E1B0Efefed;
            normie = 0x7F12d13B34F5F4f0a9449c16Bcd42f0da47AF200;
            brett = 0x532f27101965dd16442E59d40670FaF5eBB142E4;
            doginme = 0x6921B130D297cc43754afba22e5EAc0FBf8Db75b;
            tybg = 0x0d97F261b1e88845184f678e2d1e7a98D9FD38dE;
        }

        address[] memory permittedTokens = new address[](5);
        permittedTokens[0] = degen;
        permittedTokens[1] = normie;
        permittedTokens[2] = brett;
        permittedTokens[3] = doginme;
        permittedTokens[4] = tybg;

        return permittedTokens;
    }
}
