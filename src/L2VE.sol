// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.29;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

// aderyn-ignore-next-line(centralization-risk)
contract L2VE is ERC20, Ownable {
    constructor(string memory name, string memory symbol, uint256 supply) ERC20(name, symbol) Ownable(msg.sender) {
        _mint(owner(), supply);
    }
}
