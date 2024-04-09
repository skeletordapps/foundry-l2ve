// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {console2} from "forge-std/Test.sol";

contract L2VEAnyLocker is Ownable, Pausable, ReentrancyGuard {
    using SafeERC20 for ERC20;

    uint256 totalLocks;

    mapping(address token => mapping(uint256 id => LockData lockData)) public locks;
    mapping(address wallet => mapping(address token => uint256 id)) public identifiers;

    // mapping(address token => LockData lockData) public locks;

    struct LockData {
        address wallet;
        address token;
        uint256 amount;
        uint256 lockedAt;
        uint256 lockedUntil;
        uint256 unlockedAt;
    }

    event Locked(address indexed wallet, LockData lockData);
    event Unlocked(address indexed wallet, LockData lockData);

    constructor() Ownable(msg.sender) {}

    function lock(address _wallet, address _token, uint256 _amount, uint256 _lockUntil)
        external
        whenNotPaused
        nonReentrant
    {
        require(_token != address(0), "Invalid Token");
        ERC20(_token).safeTransferFrom(_wallet, address(this), _amount);

        uint256 id = identifiers[_wallet][_token];
        LockData memory newLockdata = LockData(_wallet, _token, _amount, block.timestamp, _lockUntil, 0);
        locks[_token][id] = newLockdata;

        identifiers[_wallet][_token]++;
        totalLocks++;

        emit Locked(_wallet, newLockdata);
    }

    function unlock(address _wallet, address _token, uint256 _lockId) external nonReentrant {
        LockData memory lockData = locks[_token][_lockId];

        require(lockData.token != address(0), "Token not found");
        require(msg.sender == lockData.wallet, "Not authorized");
        require(
            block.timestamp >= lockData.lockedUntil,
            string(abi.encodePacked("Unauthorized to unlock tokens until: ", lockData.lockedUntil))
        );

        lockData.unlockedAt = block.timestamp;
        locks[_token][_lockId] = lockData;

        emit Unlocked(_wallet, lockData);

        ERC20(_token).safeTransfer(lockData.wallet, lockData.amount);
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }
}
