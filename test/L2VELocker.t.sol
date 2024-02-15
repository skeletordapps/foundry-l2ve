// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import {Test, console2} from "forge-std/Test.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {L2VELocker} from "../src/L2VELocker.sol";
import {DeployLocker} from "../script/DeployLocker.s.sol";

contract L2VELockerTest is Test {
    string public RPC_URL;
    uint256 fork;

    DeployLocker deployer;
    L2VELocker locker;

    address owner;
    address bob;

    address public l2veAddress;
    ERC20 public l2ve;
    uint256 public amountToLock;

    function setUp() public {
        RPC_URL = vm.envString("BASE_RPC_URL");
        fork = vm.createFork(RPC_URL);
        vm.selectFork(fork);

        deployer = new DeployLocker();
        locker = deployer.run();

        owner = locker.owner();
        bob = vm.addr(1);
        vm.label(bob, "bob");

        l2veAddress = locker.l2veAddress();
        l2ve = ERC20(l2veAddress);
        amountToLock = locker.amountToLock();
    }

    function testConstructor() public {
        assertEq(owner, locker.multisig());
        assertFalse(locker.locked());
    }

    function testRevertLockWhenNotOwner() external {
        deal(l2veAddress, bob, amountToLock);

        vm.startPrank(bob);
        l2ve.approve(address(locker), amountToLock);

        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, bob));
        locker.lock();

        vm.stopPrank();
    }

    function testOwnerCanLockTokens() external {
        deal(l2veAddress, owner, amountToLock);

        vm.startPrank(owner);
        l2ve.approve(address(locker), amountToLock);
        locker.lock();
        vm.stopPrank();

        assertEq(l2ve.balanceOf(address(locker)), amountToLock);
        assertTrue(locker.locked());
        assertEq(l2ve.balanceOf(owner), 0);
    }

    modifier alreadyLocked() {
        deal(l2veAddress, owner, amountToLock);

        vm.startPrank(owner);
        l2ve.approve(address(locker), amountToLock);
        locker.lock();
        vm.stopPrank();
        _;
    }

    function testRevertLockIfAlreadyLocked() external alreadyLocked {
        deal(l2veAddress, owner, amountToLock);

        vm.startPrank(owner);
        l2ve.approve(address(locker), amountToLock);

        vm.expectRevert("Already locked until 1709251200");
        locker.lock();
        vm.stopPrank();
    }

    function testRevertUnlockWhenIsNotTheOwner() external alreadyLocked {
        vm.startPrank(bob);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, bob));
        locker.unlock();
        vm.stopPrank();
    }

    function testRevertUnlockWhenLockingNotHappend() external {
        vm.startPrank(owner);
        vm.expectRevert("Tokens not locked yet");
        locker.unlock();
        vm.stopPrank();
    }

    function testRevertUnlockWhenIsNotTimeYet() external alreadyLocked {
        vm.startPrank(owner);
        vm.expectRevert("Unauthorized to unlock before 1709251200");
        locker.unlock();
        vm.stopPrank();
    }

    function testOwnerCanUnlockWhenInCorrectTime() external alreadyLocked {
        vm.warp(1709251200);

        vm.startPrank(owner);
        locker.unlock();
        vm.stopPrank();

        assertEq(l2ve.balanceOf(address(locker)), 0);
        assertEq(l2ve.balanceOf(owner), amountToLock);
    }
}
