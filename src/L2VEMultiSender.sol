// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.29;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract L2VEMultiSender {
    event L2VEMultiSender__EtherSent(address indexed wallet, address[] recipients, uint256[] values);
    event L2VEMultiSender__TokenSent(address indexed wallet, ERC20 token, address[] recipients, uint256[] values);

    function sendEther(address[] memory recipients, uint256[] memory values) public payable {
        for (uint256 i = 0; i < recipients.length; i++) {
            payable(recipients[i]).transfer(values[i]);
        }

        uint256 balance = address(this).balance;
        if (balance > 0) {
            payable(msg.sender).transfer(balance);
        }

        emit L2VEMultiSender__EtherSent(msg.sender, recipients, values);
    }

    function sendToken(ERC20 token, address[] memory recipients, uint256[] memory values) external {
        uint256 total = 0;
        for (uint256 i = 0; i < recipients.length; i++) {
            total += values[i];
        }
        require(token.transferFrom(msg.sender, address(this), total));
        for (uint256 i = 0; i < recipients.length; i++) {
            require(token.transfer(recipients[i], values[i]));
        }
        emit L2VEMultiSender__TokenSent(msg.sender, token, recipients, values);
    }
}
