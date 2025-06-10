// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.29;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IL2VEFlipCoin} from "./interfaces/IL2VEFlipCoin.sol";

// aderyn-ignore-next-line(centralization-risk)
contract L2VEFlipCoin is Ownable, Pausable, ReentrancyGuard {
    using SafeERC20 for ERC20;

    address public immutable l2veAddress;
    address public immutable multisig;
    uint256 public price = 100 ether;
    uint256 public maxTicketsPerTime = 5;
    uint256 public accumulatedLosses;
    uint256 public totalWins;
    uint256 public totalLosses;

    mapping(address wallet => uint256 numberOfTickets) public tickets;
    mapping(address wallet => uint256 amount) public rewards;

    constructor(address _l2veAddress, address _multisig) Ownable(_multisig) {
        l2veAddress = _l2veAddress;
        multisig = _multisig;
        _pause();
    }

    function buy(address wallet, uint256 numOfTickets) external nonReentrant whenNotPaused {
        require(numOfTickets > 0, "Insufficient number of tickets");
        require(ERC20(l2veAddress).balanceOf(wallet) >= numOfTickets * price, "Insufficient balance");

        ERC20(l2veAddress).safeTransferFrom(wallet, address(this), numOfTickets * price);
        tickets[wallet] += numOfTickets;

        emit IL2VEFlipCoin.ticketsSold(wallet, numOfTickets);
    }

    function play(address wallet, bool choice, uint256 bets) external whenNotPaused nonReentrant returns (bool) {
        require(bets <= maxTicketsPerTime, "Exceeds max tickets per time");
        require(bets <= tickets[wallet], "Not enough tickets available to play");

        tickets[wallet] -= bets;

        uint256 randomValue = random();
        bool result = randomValue % 2 == 0; // Heads for even, Tails for odd
        bool isWinner = result == choice;

        if (isWinner) {
            rewards[wallet] += bets * price;
            totalWins++;
        } else {
            accumulatedLosses += bets * price;
            totalLosses++;
        }

        emit IL2VEFlipCoin.played(wallet, bets, isWinner);

        return isWinner;
    }

    function claim(address wallet) external whenNotPaused nonReentrant {
        require(rewards[wallet] > 0, "No rewards available to claim");

        uint256 userRewards = rewards[wallet];
        require(ERC20(l2veAddress).balanceOf(address(this)) >= userRewards, "Insufficient balance to claim");

        rewards[wallet] = 0;
        emit IL2VEFlipCoin.claimed(wallet, userRewards);

        ERC20(l2veAddress).safeTransfer(wallet, userRewards);
    }

    function convertInTickets(address wallet) external whenNotPaused nonReentrant {
        require(rewards[wallet] > 0, "No rewards available to convert in tickets");

        uint256 newTickets = rewards[wallet] / price;
        rewards[wallet] = 0;
        tickets[wallet] += newTickets;

        emit IL2VEFlipCoin.rewardsToTicketsConversion(wallet, newTickets);
    }

    function setPrice(uint256 _price) external onlyOwner nonReentrant {
        require(_price > 0, "Cannot be zero");
        price = _price;
    }

    function setMaxTicketsPerTime(uint256 _maxTicketsPerTime) external onlyOwner nonReentrant {
        require(_maxTicketsPerTime > 0, "Cannot be zero");
        maxTicketsPerTime = _maxTicketsPerTime;
    }

    function withdrawLosses() external onlyOwner nonReentrant {
        uint256 accumulatedLossesCopy = accumulatedLosses;
        accumulatedLosses = 0;
        emit IL2VEFlipCoin.withdrawLosses(accumulatedLossesCopy);

        ERC20(l2veAddress).safeTransfer(owner(), accumulatedLossesCopy);
    }

    function withdraw() external onlyOwner {
        pause();
        uint256 balance = ERC20(l2veAddress).balanceOf(address(this));
        ERC20(l2veAddress).safeTransfer(owner(), balance);
        emit IL2VEFlipCoin.withdraw(balance);
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    function random() public view returns (uint256) {
        uint256 seed = uint256(
            keccak256(
                abi.encodePacked(
                    block.timestamp + block.prevrandao
                        + ((uint256(keccak256(abi.encodePacked(block.coinbase)))) / (block.timestamp)) + block.gaslimit
                        + ((uint256(keccak256(abi.encodePacked(msg.sender)))) / (block.timestamp)) + block.number
                )
            )
        );

        return (seed - ((seed / 1000) * 1000));
    }
}
