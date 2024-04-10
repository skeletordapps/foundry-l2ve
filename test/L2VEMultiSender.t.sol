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

    ERC20 public constant L2VE = ERC20(0xA19328fb05ce6FD204D16c2a2A98F7CF434c12F4);

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
    //     vm.deal(bob, 20 ether); // send 20 ether to bob's wallet

    //     address[] memory recipients = new address[](1);
    //     recipients[0] = john;

    //     uint256[] memory values = new uint256[](1);
    //     values[0] = 2 ether;

    //     console2.log(john.balance);

    //     vm.startPrank(bob);
    //     ms.sendEther{value: 3 ether}(recipients, values);
    //     vm.stopPrank();

    //     console2.log(john.balance);

    //     // assertEq(john.balance, johnBalance + 2 ether);
    // }

    function testCanSendTokenToMultipleWallets() external {
        address[] memory recipients = new address[](3);
        recipients[0] = john;
        recipients[1] = alexa;
        recipients[2] = sheila;

        uint256[] memory values = new uint256[](3);
        values[0] = 2 ether;
        values[1] = 5 ether;
        values[2] = 10 ether;

        assertEq(L2VE.balanceOf(john), 0);
        assertEq(L2VE.balanceOf(alexa), 0);
        assertEq(L2VE.balanceOf(sheila), 0);

        vm.startPrank(bob);
        L2VE.approve(address(ms), 17 ether);
        ms.sendToken(L2VE, recipients, values);
        vm.stopPrank();
    }
}
