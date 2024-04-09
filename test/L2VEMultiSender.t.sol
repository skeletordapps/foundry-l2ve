// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import {Test, console2} from "forge-std/Test.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import {L2VEMultiSender} from "../src/L2VEMultiSender.sol";
import {DeployMultiSender} from "../script/DeployMultiSender.s.sol";

contract L2VEMultiSenderTest is Test {
    string public RPC_URL;
    uint256 fork;

    DeployMultiSender deployer;
    L2VEMultiSender ms;

    address bob;
    address john;
    address alexa;
    address sheila;

    function setUp() public {
        RPC_URL = vm.envString("BASE_RPC_URL");
        fork = vm.createFork(RPC_URL);
        vm.selectFork(fork);

        deployer = new DeployMultiSender();
        ms = deployer.run();

        bob = vm.addr(1);
        vm.label(bob, "bob");

        john = vm.addr(1);
        vm.label(john, "john");

        alexa = vm.addr(1);
        vm.label(alexa, "alexa");

        sheila = vm.addr(1);
        vm.label(sheila, "sheila");
    }

    // function testCanSendEtherToMultipleWallets() external {
    //     address[] memory recipients = new address[](3);
    //     recipients[0] = john;
    //     recipients[1] = alexa;
    //     recipients[2] = sheila;

    //     uint256[] memory values = new uint256[](3);
    //     values[0] = 2 ether;
    //     values[1] = 5 ether;
    //     values[2] = 10 ether;

    //     // uint256 johnBalance = john.balance;
    //     // uint256 alexaBalance = alexa.balance;
    //     // uint256 sheilaBalance = sheila.balance;

    //     // vm.startPrank(bob);
    //     // ms.sendEther(recipients, values);
    //     // vm.stopPrank();

    //     // assertEq(john.balance, johnBalance + 2 ether);
    //     // assertEq(alexa.balance, alexaBalance + 5 ether);
    //     // assertEq(sheila.balance, sheilaBalance + 10 ether);
    // }
}
