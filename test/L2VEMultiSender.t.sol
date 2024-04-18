// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import {Test, console2} from "forge-std/Test.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {L2VEMultiSender} from "../src/L2VEMultiSender.sol";
import {DeployMultiSender} from "../script/DeployMultiSender.s.sol";

contract L2VEMultiSenderTest is Test {
    using SafeERC20 for ERC20;

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

        john = vm.addr(2);
        vm.label(john, "john");

        alexa = vm.addr(3);
        vm.label(alexa, "alexa");

        sheila = vm.addr(4);
        vm.label(sheila, "sheila");
    }

    function testCanSendEtherToMultipleWallets() external {
        address[] memory recipients = new address[](3);
        recipients[0] = john;
        recipients[1] = alexa;
        recipients[2] = sheila;

        uint256[] memory values = new uint256[](3);
        values[0] = 2 ether;
        values[1] = 5 ether;
        values[2] = 10 ether;

        uint256 johnInitialBalance = john.balance;
        uint256 alexaInitialBalance = alexa.balance;
        uint256 sheilaInitialBalance = sheila.balance;
        vm.deal(bob, 17 ether);

        vm.startPrank(bob);
        ms.sendEther{value: 17 ether}(recipients, values);
        vm.stopPrank();

        assertEq(john.balance, values[0] + johnInitialBalance);
        assertEq(alexa.balance, values[1] + alexaInitialBalance);
        assertEq(sheila.balance, values[2] + sheilaInitialBalance);
    }

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

        deal(address(L2VE), bob, 17 ether);

        vm.startPrank(bob);
        L2VE.forceApprove(address(ms), 17 ether);
        ms.sendToken(L2VE, recipients, values);
        vm.stopPrank();

        assertEq(L2VE.balanceOf(john), values[0]);
        assertEq(L2VE.balanceOf(alexa), values[1]);
        assertEq(L2VE.balanceOf(sheila), values[2]);
    }
}
