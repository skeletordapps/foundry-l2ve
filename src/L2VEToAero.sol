// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.29;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
// import {console} from "forge-std/console.sol";

// aderyn-ignore-next-line(centralization-risk)
contract L2VEToAero is Ownable, Pausable, ReentrancyGuard {
    using SafeERC20 for ERC20;

    uint256 public constant AERO_PER_L2VE = 0.00037434 ether;
    address public constant L2VE_ADDRESS = 0xA19328fb05ce6FD204D16c2a2A98F7CF434c12F4;
    address public constant MULTISIG_ADDRESS = 0x7B2871c2dcad6f2B396fE7E1a087Ae6170f4131C;
    address public constant AERO_ADDRESS = 0x940181a94A35A4569E4529A3CDfB74e38FD98631;

    ERC20 public immutable l2ve;
    ERC20 public immutable aero;

    mapping(address account => mapping(uint256 timestamp => uint256 l2veAmount)) public entries;
    mapping(address account => mapping(uint256 timestamp => uint256 aeroAmount)) public outs;

    event Swapped(address indexed account, uint256 l2veAmount, uint256 aeroAmount, uint256 timestamp);
    event Withdrawal(address indexed account, uint256 l2veAmount);
    event EmergencyWithdrawal(address indexed account, uint256 l2veAmount, uint256 aeroAmount);

    constructor() Ownable(MULTISIG_ADDRESS) {
        l2ve = ERC20(L2VE_ADDRESS);
        aero = ERC20(AERO_ADDRESS);
    }

    // aderyn-ignore-next-line(eth-send-unchecked-address)
    function swap(uint256 l2veAmount) external nonReentrant whenNotPaused {
        require(l2veAmount > 0, "Cannot be zero");

        address sender = msg.sender;
        l2ve.safeTransferFrom(sender, address(this), l2veAmount);

        uint256 aeroAmount = ratioAmount(l2veAmount);
        uint256 timestamp = block.timestamp;
        entries[sender][timestamp] += l2veAmount;
        outs[sender][timestamp] += aeroAmount;

        require(aero.balanceOf(address(this)) >= aeroAmount, "Insufficient balance of Aero");
        emit Swapped(sender, l2veAmount, aeroAmount, timestamp);

        aero.safeTransfer(sender, aeroAmount);
    }

    /// @notice Pause the contract, preventing further locking actions
    /// aderyn-ignore-next-line(centralization-risk)
    function pause() external onlyOwner {
        _pause();
    }

    /// @notice Unpause the contract, allowing locking actions again
    /// aderyn-ignore-next-line(centralization-risk)
    function unpause() external onlyOwner {
        _unpause();
    }

    // aderyn-ignore-next-line(centralization-risk)
    function withdraw() external nonReentrant onlyOwner {
        uint256 balance = l2ve.balanceOf(address(this));
        l2ve.safeTransfer(MULTISIG_ADDRESS, balance);
        emit Withdrawal(MULTISIG_ADDRESS, balance);
    }

    // aderyn-ignore-next-line(centralization-risk)
    function emergencyWithdraw() external nonReentrant onlyOwner {
        uint256 l2veBalance = l2ve.balanceOf(address(this));
        uint256 aeroBalance = aero.balanceOf(address(this));
        l2ve.safeTransfer(MULTISIG_ADDRESS, l2veBalance);
        aero.safeTransfer(MULTISIG_ADDRESS, aeroBalance);
        emit EmergencyWithdrawal(MULTISIG_ADDRESS, l2veBalance, aeroBalance);
    }

    function ratioAmount(uint256 amount) private pure returns (uint256) {
        return amount * AERO_PER_L2VE / 1 ether;
    }
}
