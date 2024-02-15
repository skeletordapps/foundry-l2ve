// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract L2VELocker is Ownable {
    using SafeERC20 for ERC20;

    address public l2veAddress = 0xA19328fb05ce6FD204D16c2a2A98F7CF434c12F4;
    address public multisig = 0x7B2871c2dcad6f2B396fE7E1a087Ae6170f4131C;
    uint256 public lockedUntil = 1709251200;
    uint256 public amountToLock = 50_000_000 ether;
    bool public locked;

    constructor() Ownable(multisig) {}

    function lock() external onlyOwner {
        require(!locked, "Already locked until 1709251200");
        ERC20(l2veAddress).safeTransferFrom(multisig, address(this), amountToLock);
        locked = true;
    }

    function unlock() external onlyOwner {
        require(locked, "Tokens not locked yet");
        require(block.timestamp >= lockedUntil, "Unauthorized to unlock before 1709251200");

        ERC20 l2ve = ERC20(l2veAddress);
        l2ve.safeTransfer(multisig, l2ve.balanceOf(address(this)));
    }
}
