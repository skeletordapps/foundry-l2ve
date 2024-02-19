// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

interface IL2VEFlipCoin {
    event ticketsSold(address indexed wallet, uint256 numOfTickets);
    event played(address indexed wallet, uint256 numOfBets, bool result);
    event claimed(address indexed wallet, uint256 amount);
    event withdrawal(uint256 amount);
    event rewardsToTicketsConversion(address indexed wallet, uint256 tickets);
    event withdrawLosses(uint256 amount);
    event withdraw(uint256 amount);
}
