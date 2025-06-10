// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.29;

import {Test} from "forge-std/Test.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {console} from "forge-std/console.sol";

import {L2VEToAero} from "../src/L2VEToAero.sol";
import {DeployL2VEToAero} from "../script/DeployL2VEToAero.s.sol";

contract L2VEToAeroTest is Test {
    string public RPC_URL;
    uint256 fork;

    DeployL2VEToAero deployer;
    L2VEToAero swapper;

    ERC20 l2ve;
    ERC20 aero;

    address owner;
    address bob;
    address mary;

    event Swapped(address indexed account, uint256 l2veAmount, uint256 aeroAmount, uint256 timestamp);
    event Withdrawal(address indexed account, uint256 l2veAmount);
    event EmergencyWithdrawal(address indexed account, uint256 l2veAmount, uint256 aeroAmount);

    function setUp() public {
        RPC_URL = vm.envString("BASE_RPC_URL");
        fork = vm.createFork(RPC_URL);
        vm.selectFork(fork);

        deployer = new DeployL2VEToAero();
        swapper = deployer.run();

        owner = swapper.owner();
        l2ve = swapper.l2ve();
        aero = swapper.aero();

        bob = vm.addr(1);
        vm.label(bob, "bob");

        mary = vm.addr(2);
        vm.label(mary, "mary");
    }

    function testConstructor() public view {
        assertEq(l2ve.balanceOf(address(swapper)), 0);
        assertEq(aero.balanceOf(address(swapper)), 0);
        assertEq(owner, swapper.MULTISIG_ADDRESS());
    }

    function testSwapRevertWithInvalidAmount() external {
        vm.startPrank(bob);
        vm.expectRevert("Cannot be zero");
        swapper.swap(0);
        vm.stopPrank();
    }

    function testSwapRevertWhenContractHasNoAero() external {
        uint256 l2veAmount = 1000 ether;
        deal(address(l2ve), bob, l2veAmount);
        assertEq(l2ve.balanceOf(bob), l2veAmount);

        vm.startPrank(bob);
        l2ve.approve(address(swapper), l2veAmount);

        vm.expectRevert("Insufficient balance of Aero");
        swapper.swap(l2veAmount);
        vm.stopPrank();
    }

    function testCanSwap() external {
        uint256 l2veAmount = 1000 ether;
        uint256 aeroAmount = 500 ether;
        uint256 expectedAeroAmount = 0.37434 ether;

        deal(address(l2ve), bob, l2veAmount);
        deal(address(aero), address(swapper), aeroAmount);

        assertEq(l2ve.balanceOf(bob), l2veAmount);
        assertEq(aero.balanceOf(bob), 0);

        vm.startPrank(bob);
        l2ve.approve(address(swapper), l2veAmount);

        vm.expectEmit(true, true, true, false);
        emit Swapped(bob, l2veAmount, expectedAeroAmount, block.timestamp);
        swapper.swap(l2veAmount);
        vm.stopPrank();

        assertEq(l2ve.balanceOf(bob), 0);
        assertEq(aero.balanceOf(bob), expectedAeroAmount);
        assertEq(swapper.entries(bob, block.timestamp), l2veAmount);
        assertEq(swapper.outs(bob, block.timestamp), expectedAeroAmount);
    }

    modifier dealAero(uint256 amount) {
        deal(address(aero), address(swapper), amount);
        _;
    }

    modifier swapped(address account, uint256 amount) {
        deal(address(l2ve), account, amount);
        vm.startPrank(account);
        l2ve.approve(address(swapper), amount);
        swapper.swap(amount);
        vm.stopPrank();
        _;
    }

    function testCanWithdrawFunds() external dealAero(500 ether) swapped(bob, 500 ether) swapped(mary, 700 ether) {
        uint256 initialBalance = l2ve.balanceOf(owner);

        vm.startPrank(owner);
        vm.expectEmit(true, true, true, true);
        emit Withdrawal(owner, 1200 ether);
        swapper.withdraw();
        vm.stopPrank();

        assertEq(l2ve.balanceOf(owner), initialBalance + 1200 ether);
    }

    function testCanEmergencyWithdraw() external dealAero(500 ether) swapped(bob, 500 ether) {
        uint256 totalAeroSent = 500 ether;
        uint256 ratio = swapper.AERO_PER_L2VE();
        uint256 totalSwapped = 500 ether * ratio / 1 ether; // aero that bob received
        uint256 expectedAeroBalance = totalAeroSent - totalSwapped; // initial amount - aero bob received

        assertEq(aero.balanceOf(address(swapper)), expectedAeroBalance); // amount of aero in contract after swap

        deal(address(aero), owner, 1000 ether);

        vm.startPrank(owner);
        aero.transfer(address(swapper), 500 ether);
        vm.stopPrank();

        expectedAeroBalance += 500 ether;
        assertEq(aero.balanceOf(address(swapper)), expectedAeroBalance);

        vm.startPrank(owner);
        vm.expectEmit(true, true, true, true);
        emit EmergencyWithdrawal(owner, 500 ether, expectedAeroBalance);
        swapper.emergencyWithdraw();
        vm.stopPrank();

        // owner aero & l2ve balance
        assertEq(aero.balanceOf(owner), expectedAeroBalance + 500 ether);
        assertEq(l2ve.balanceOf(owner), 500 ether);

        // contract aero & l2ve balance
        assertEq(aero.balanceOf(address(swapper)), 0);
        assertEq(l2ve.balanceOf(address(swapper)), 0);
    }
}
