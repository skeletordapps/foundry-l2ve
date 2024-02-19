// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import {Test, console2} from "forge-std/Test.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {L2VEFlipCoin} from "../src/L2VEFlipCoin.sol";
import {DeployFlipCoin} from "../script/DeployFlipCoin.s.sol";
import {IL2VEFlipCoin} from "../src/interfaces/IL2VEFlipCoin.sol";

contract L2VEFlipCoinTest is Test {
    string public RPC_URL;
    uint256 fork;

    DeployFlipCoin deployer;
    L2VEFlipCoin flipCoin;

    address owner;
    address bob;
    address mary;
    address john;

    address public l2veAddress;
    ERC20 public l2ve;

    uint256 price;

    function setUp() public {
        RPC_URL = vm.envString("BASE_RPC_URL");
        fork = vm.createFork(RPC_URL);
        vm.selectFork(fork);

        deployer = new DeployFlipCoin();
        flipCoin = deployer.run();

        owner = flipCoin.owner();
        bob = vm.addr(1);
        vm.label(bob, "bob");

        mary = vm.addr(2);
        vm.label(mary, "mary");

        john = vm.addr(3);
        vm.label(john, "john");

        l2veAddress = flipCoin.l2veAddress();
        l2ve = ERC20(l2veAddress);

        price = flipCoin.price();
    }

    function testConstructor() public {
        assertEq(owner, flipCoin.multisig());
        assertEq(flipCoin.maxTicketsPerTime(), 5);
        assertTrue(flipCoin.paused());
    }

    modifier notPaused() {
        vm.startPrank(owner);
        flipCoin.unpause();
        vm.stopPrank();

        assertFalse(flipCoin.paused());
        _;
    }

    function testRevertBuyWithInsufficientNumOfTickets() external notPaused {
        vm.startPrank(bob);
        vm.expectRevert("Insufficient number of tickets");
        flipCoin.buy(bob, 0);
        vm.stopPrank();
    }

    function testRevertBuyWithInsufficientBalance() external notPaused {
        vm.startPrank(bob);
        vm.expectRevert("Insufficient balance");
        flipCoin.buy(bob, price);
        vm.stopPrank();
    }

    modifier hasBalance(address wallet, uint256 amount) {
        deal(l2veAddress, wallet, amount);
        _;
    }

    function testCanBuy2Tickets() external notPaused hasBalance(bob, price * 2) {
        vm.startPrank(bob);
        l2ve.approve(address(flipCoin), price * 2);
        flipCoin.buy(bob, 2);
        vm.stopPrank();

        assertEq(flipCoin.tickets(bob), 2);
        assertEq(l2ve.balanceOf(address(flipCoin)), price * 2);
    }

    modifier hasTickets(address wallet, uint256 numOfTickets) {
        vm.startPrank(wallet);
        l2ve.approve(address(flipCoin), price * numOfTickets);
        flipCoin.buy(wallet, numOfTickets);
        vm.stopPrank();
        _;
    }

    function testRevertPlayWhenExceedsMaxTicketsPerTime()
        external
        notPaused
        hasBalance(bob, price * 2)
        hasTickets(bob, 2)
    {
        vm.startPrank(bob);
        vm.expectRevert("Exceeds max tickets per time");
        flipCoin.play(bob, true, 10);
        vm.stopPrank();
    }

    function testRevertPlayWhenNotEnoughTicketsAvailableToPlay()
        external
        notPaused
        hasBalance(bob, price * 2)
        hasTickets(bob, 2)
    {
        vm.startPrank(bob);
        vm.expectRevert("Not enough tickets available to play");
        flipCoin.play(bob, true, 3);
        vm.stopPrank();
    }

    function testCanPlay() external notPaused {
        deal(l2veAddress, bob, price * 5);
        vm.startPrank(bob);
        l2ve.approve(address(flipCoin), price * 5);
        flipCoin.buy(bob, 5);
        vm.stopPrank();

        deal(l2veAddress, mary, price);
        vm.startPrank(mary);
        l2ve.approve(address(flipCoin), price);
        flipCoin.buy(mary, 1);
        vm.stopPrank();

        deal(l2veAddress, john, price * 3);
        vm.startPrank(john);
        l2ve.approve(address(flipCoin), price * 3);
        flipCoin.buy(john, 3);
        vm.stopPrank();

        address[3] memory users;
        users[0] = bob;
        users[1] = mary;
        users[2] = john;

        for (uint256 i = 0; i < users.length; i++) {
            uint256 tickets = flipCoin.tickets(users[i]);

            uint256 rewardsBefore = flipCoin.rewards(users[i]);

            vm.warp(block.timestamp + 1 hours);
            vm.startPrank(users[i]);
            bool isWinner = flipCoin.play(users[i], true, tickets);
            vm.stopPrank();

            uint256 rewardsAfter = flipCoin.rewards(users[i]);

            if (isWinner) {
                assertEq(rewardsAfter, rewardsBefore + price);
            } else {
                assertEq(rewardsAfter, rewardsBefore);
            }
        }

        assertEq(flipCoin.tickets(bob), 0);
        assertEq(flipCoin.tickets(mary), 0);
        assertEq(flipCoin.tickets(john), 0);
    }

    modifier usersPlayed() {
        deal(l2veAddress, bob, price * 5);
        vm.startPrank(bob);
        l2ve.approve(address(flipCoin), price * 5);
        flipCoin.buy(bob, 5);
        vm.stopPrank();

        deal(l2veAddress, mary, price);
        vm.startPrank(mary);
        l2ve.approve(address(flipCoin), price);
        flipCoin.buy(mary, 1);
        vm.stopPrank();

        deal(l2veAddress, john, price * 3);
        vm.startPrank(john);
        l2ve.approve(address(flipCoin), price * 3);
        flipCoin.buy(john, 3);
        vm.stopPrank();

        address[3] memory users;
        users[0] = bob;
        users[1] = mary;
        users[2] = john;

        for (uint256 i = 0; i < users.length; i++) {
            uint256 tickets = flipCoin.tickets(users[i]);

            vm.warp(block.timestamp + 1 hours);
            vm.startPrank(users[i]);
            flipCoin.play(users[i], true, tickets);
            vm.stopPrank();
        }
        _;
    }

    function testRevertClaimWhenHasNoRewards() external notPaused {
        vm.startPrank(bob);
        vm.expectRevert("No rewards available to claim");
        flipCoin.claim(bob);
        vm.stopPrank();
    }

    function testCanClaim() external notPaused usersPlayed {
        address[3] memory users;
        users[0] = bob;
        users[1] = mary;
        users[2] = john;

        for (uint256 i = 0; i < users.length; i++) {
            uint256 rewards = flipCoin.rewards(users[i]);

            if (rewards > 0) {
                vm.startPrank(users[i]);
                vm.expectEmit(true, true, true, true);
                emit IL2VEFlipCoin.claimed(users[i], rewards);
                flipCoin.claim(users[i]);
                vm.stopPrank();

                assertEq(flipCoin.rewards(users[i]), 0);
                assertEq(l2ve.balanceOf(users[i]), rewards);
            }
        }
    }

    function testRevertConvertInTicketsWhenHasNoRewards() external notPaused {
        vm.startPrank(bob);
        vm.expectRevert("No rewards available to convert in tickets");
        flipCoin.convertInTickets(bob);
        vm.stopPrank();
    }

    function testCanConverRewardsInTickets() external notPaused usersPlayed {
        address[3] memory users;
        users[0] = bob;
        users[1] = mary;
        users[2] = john;

        for (uint256 i = 0; i < users.length; i++) {
            uint256 rewards = flipCoin.rewards(users[i]);

            if (rewards > 0) {
                vm.startPrank(users[i]);
                vm.expectEmit(true, true, true, true);
                uint256 numOfTickets = rewards / price;
                emit IL2VEFlipCoin.rewardsToTicketsConversion(users[i], numOfTickets);
                flipCoin.convertInTickets(users[i]);
                vm.stopPrank();

                assertEq(flipCoin.rewards(users[i]), 0);
                assertEq(flipCoin.tickets(users[i]), numOfTickets);
            }
        }
    }

    function testCanWithdrawLosses() external notPaused usersPlayed {
        uint256 accumulatedLosses = flipCoin.accumulatedLosses();
        uint256 balance = l2ve.balanceOf(owner);

        if (accumulatedLosses > 0) {
            vm.startPrank(owner);
            vm.expectEmit(true, true, true, true);
            emit IL2VEFlipCoin.withdrawLosses(accumulatedLosses);
            flipCoin.withdrawLosses();
            vm.stopPrank();

            assertEq(flipCoin.accumulatedLosses(), 0);
            assertEq(l2ve.balanceOf(owner), balance + accumulatedLosses);
        }
    }

    function testCanWithdraw() external notPaused {
        vm.startPrank(owner);

        l2ve.transfer(address(flipCoin), 10 ether);
        assertEq(l2ve.balanceOf(address(flipCoin)), 10 ether);

        uint256 ownerBalance = l2ve.balanceOf(owner);
        uint256 flipCoinBalance = l2ve.balanceOf(address(flipCoin));

        flipCoin.withdraw();

        uint256 ownerBalanceEnd = l2ve.balanceOf(owner);
        uint256 flipCoinBalanceEnd = l2ve.balanceOf(address(flipCoin));

        assertEq(ownerBalanceEnd, ownerBalance + flipCoinBalance);
        assertEq(flipCoinBalanceEnd, 0);

        vm.stopPrank();
    }

    function testCanSendL2VEToContract() external {
        vm.startPrank(owner);
        l2ve.transfer(address(flipCoin), 1_000 ether);
        vm.stopPrank();

        uint256 balance = l2ve.balanceOf(address(flipCoin));
        assertEq(balance, 1_000 ether);
    }

    function testRevertSetPriceWhenZero() external {
        vm.startPrank(owner);
        vm.expectRevert("Cannot be zero");
        flipCoin.setPrice(0);
        vm.stopPrank();
    }

    function testOwnerCanSetPrice() external {
        uint256 newPrice = price * 2;
        vm.startPrank(owner);
        flipCoin.setPrice(newPrice);
        vm.stopPrank();

        assertEq(flipCoin.price(), newPrice);
    }

    function testRevertSetMaxTicketsPerTimeWhenZero() external {
        vm.startPrank(owner);
        vm.expectRevert("Cannot be zero");
        flipCoin.setMaxTicketsPerTime(0);
        vm.stopPrank();
    }

    function testOwnerCanSetMaxTicketsPerTime() external {
        vm.startPrank(owner);
        flipCoin.setMaxTicketsPerTime(10);
        vm.stopPrank();

        assertEq(flipCoin.maxTicketsPerTime(), 10);
    }
}
