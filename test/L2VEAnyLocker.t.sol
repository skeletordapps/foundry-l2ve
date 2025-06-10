// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.29;

import {Test} from "forge-std/Test.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import {L2VEAnyLocker} from "../src/L2VEAnyLocker.sol";
import {DeployAnyLocker} from "../script/DeployAnyLocker.s.sol";

contract L2VEAnyLockerTest is Test {
    string public RPC_URL;
    uint256 fork;

    DeployAnyLocker deployer;
    L2VEAnyLocker locker;

    address owner;
    address bob;
    address mary;

    address public l2veAddress;
    ERC20 public l2ve;
    uint256 public amountToLock;

    address WETH = vm.envAddress("BASE_WETH_ADDRESS");

    function setUp() public {
        RPC_URL = vm.envString("BASE_RPC_URL");
        fork = vm.createFork(RPC_URL);
        vm.selectFork(fork);

        deployer = new DeployAnyLocker();
        locker = deployer.run();

        owner = locker.owner();

        bob = vm.addr(1);
        vm.label(bob, "bob");

        mary = vm.addr(2);
        vm.label(mary, "mary");
    }

    function testLockRevertWhenInvalidAddress() external {
        vm.startPrank(bob);
        vm.expectRevert("Invalid Token");
        locker.lock(bob, address(0x0), 10 ether, 10 days);
        vm.stopPrank();
    }

    function testCanLockToken() external {
        deal(WETH, bob, 100 ether);

        vm.startPrank(bob);
        ERC20(WETH).approve(address(locker), 100 ether);
        vm.expectEmit(true, true, true, true);
        emit L2VEAnyLocker.Locked(
            bob, L2VEAnyLocker.LockData(bob, WETH, 100 ether, block.timestamp, block.timestamp + 10 days, 0)
        );
        locker.lock(bob, WETH, 100 ether, block.timestamp + 10 days);

        vm.stopPrank();
    }

    modifier hasLocked() {
        deal(WETH, bob, 100 ether);

        vm.startPrank(bob);
        ERC20(WETH).approve(address(locker), 100 ether);
        locker.lock(bob, WETH, 100 ether, block.timestamp + 10 days);
        vm.stopPrank();
        _;
    }

    function testUnlockRevertWhenInvalidToken() external hasLocked {
        vm.startPrank(bob);
        vm.expectRevert("Token not found");
        locker.unlock(bob, address(0x0), 0);
        vm.stopPrank();
    }

    function testUnlockRevertWhenUnauthorizedWallet() external hasLocked {
        vm.startPrank(mary);
        vm.expectRevert("Not authorized");
        locker.unlock(mary, WETH, 0);
        vm.stopPrank();
    }

    function testUnlockRevertWhenBeforeUnlockTime() external hasLocked {
        uint256 lockId = locker.identifiers(bob, WETH) - 1;
        string memory expectedError =
            string(abi.encodePacked("Unauthorized to unlock tokens until: ", block.timestamp + 10 days));

        vm.startPrank(bob);
        vm.expectRevert(bytes(expectedError));
        locker.unlock(bob, WETH, lockId);
        vm.stopPrank();
    }

    function testCanUnlock() external hasLocked {
        uint256 lockId = locker.identifiers(bob, WETH) - 1;
        (, address token, uint256 amount, uint256 lockedAt, uint256 lockedUntil,) = locker.locks(WETH, lockId);
        uint256 expectedUnlockedAt = lockedUntil + 1 days;

        vm.warp(expectedUnlockedAt);

        vm.startPrank(bob);
        vm.expectEmit(true, true, true, true);
        emit L2VEAnyLocker.Unlocked(
            bob, L2VEAnyLocker.LockData(bob, token, amount, lockedAt, lockedUntil, expectedUnlockedAt)
        );
        locker.unlock(bob, token, lockId);
        vm.stopPrank();

        (,,,,, uint256 unlockedAt) = locker.locks(WETH, lockId);

        assertEq(unlockedAt, expectedUnlockedAt);
        assertEq(ERC20(WETH).balanceOf(address(locker)), 0);
        assertEq(ERC20(WETH).balanceOf(bob), amount);
    }
}
