// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import {console2} from "forge-std/Test.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IBaseSwapRouter} from "./interfaces/IBaseSwapRouter.sol";

contract Meme is ERC20, Ownable, ReentrancyGuard {
    using SafeERC20 for ERC20;

    // Tax-related variables
    address public wethAddress; // Weth address
    address public routerAddress; // Address of the DEX router
    uint256 public buyTax = 5; // Buy tax percentage
    uint256 public sellTax = 5; // Sell tax percentage
    address public treasuryWallet; // Address of the treasury wallet

    error Meme__InvalidAddress(string message);
    error Meme__Error(string message);

    event ConfigUpdated(string config, bytes value);

    constructor(string memory _name, string memory _symbol, address _routerAddress, address _wethAddress)
        ERC20(_name, _symbol)
        Ownable(msg.sender)
    {
        if (_routerAddress == address(0)) revert Meme__InvalidAddress("Invalid address");
        if (IBaseSwapRouter(_routerAddress).WETH() != _wethAddress) {
            revert Meme__InvalidAddress("Invalid WETH address for router");
        }

        routerAddress = _routerAddress; // Set the router address
        wethAddress = _wethAddress; // Set weth address of the network chain
        treasuryWallet = msg.sender; // Set the treasury wallet to deployer by default

        _mint(msg.sender, 100_000_000 ether);
    }

    function transfer(address recipient, uint256 amount) public override nonReentrant returns (bool) {
        uint256 taxAmount;

        console2.log("msg.sender == routerAddress", msg.sender == routerAddress);
        console2.log("recipient == routerAddress", recipient == routerAddress);

        // Apply buy or sell tax based on sender/receiver relationship
        if (msg.sender == routerAddress) {
            // Selling on a DEX
            taxAmount = amount * sellTax / 100;
            if (amount < taxAmount) revert Meme__Error("Insufficient token balance for sell transaction");
        } else if (recipient == routerAddress) {
            // Buying on a DEX
            taxAmount = amount * buyTax / 100;
            if (amount < taxAmount) revert Meme__Error("Insufficient token balance for buy transaction");
        }

        if (taxAmount > 0) {
            uint256[] memory amounts = _swapTokensForEth(treasuryWallet, taxAmount);
            console2.log(amounts[0]);

            if (balanceOf(treasuryWallet) < balanceOf(treasuryWallet) - taxAmount) {
                revert Meme__Error("Swap failed to transfer tax tokens");
            }
        }

        _transfer(msg.sender, recipient, amount - taxAmount); // Transfer remaining tokens

        return true;
    }

    function _swapTokensForEth(address recipient, uint256 amount) internal returns (uint256[] memory amounts) {
        IBaseSwapRouter router = IBaseSwapRouter(routerAddress);
        ERC20 token = ERC20(address(this));

        // Approve router to spend tax tokens
        token.approve(address(router), amount);

        // Define swap path (your token -> WETH)
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = wethAddress;

        // Call the swap function on the router
        (amounts) = router.swapExactTokensForETH(
            amount,
            0, // Minimum acceptable ETH output (adjust as needed)
            path,
            recipient,
            block.timestamp
        );

        return amounts;
    }

    function createLiquidityPair(uint256 wethAmount, uint256 tokenAmount)
        external
        onlyOwner
        nonReentrant
        returns (uint256 amountA, uint256 amountB, uint256 liquidity)
    {
        IBaseSwapRouter router = IBaseSwapRouter(routerAddress);
        ERC20 weth = ERC20(router.WETH());

        // Transfer WETH from owner to contract
        weth.safeTransferFrom(owner(), address(this), wethAmount);

        // Transfer Meme tokens from owner to contract
        _transfer(owner(), address(this), tokenAmount);

        // Check if the contract has enough Meme tokens and WETH
        require(weth.balanceOf(address(this)) >= wethAmount, "Insufficient WETH");
        require(balanceOf(address(this)) >= tokenAmount, "Insufficient Meme tokens");

        // Approve the router to spend tokens
        ERC20(address(this)).approve(routerAddress, tokenAmount);
        weth.approve(routerAddress, wethAmount);

        (amountA, amountB, liquidity) =
            router.addLiquidity(address(weth), address(this), wethAmount, tokenAmount, 0, 0, owner(), block.timestamp);

        return (amountA, amountB, liquidity);
    }

    function updateBuyTax(uint256 _buyTax) external onlyOwner nonReentrant {
        buyTax = _buyTax;
        emit ConfigUpdated("buyTax", abi.encodePacked(_buyTax));
    }

    function updateSellTax(uint256 _sellTax) external onlyOwner nonReentrant {
        sellTax = _sellTax;
        emit ConfigUpdated("sellTax", abi.encodePacked(_sellTax));
    }

    function updateTreasuryWallet(address _treasuryWallet) external onlyOwner nonReentrant {
        if (_treasuryWallet == address(0)) revert Meme__InvalidAddress("Invalid treasury wallet");

        treasuryWallet = _treasuryWallet; // Only owner can change the treasury wallet
        emit ConfigUpdated("treasuryWallet", abi.encodePacked(_treasuryWallet));
    }
}
