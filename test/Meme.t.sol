// // SPDX-License-Identifier: UNLICENSED
// pragma solidity ^0.8.23;

// import {Test, console2} from "forge-std/Test.sol";
// import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// import {Meme} from "../src/Meme.sol";
// import {DeployMeme} from "../script/DeployMeme.s.sol";
// import {IBaseSwapRouter} from "../src/interfaces/IBaseSwapRouter.sol";

// contract MemeTest is Test {
//     string public RPC_URL;
//     uint256 fork;

//     DeployMeme deployer;
//     Meme meme;

//     address routerAddress;
//     address wethAddress;

//     address owner;
//     address bob;

//     function setUp() public {
//         RPC_URL = vm.envString("BASE_RPC_URL");
//         fork = vm.createFork(RPC_URL);
//         vm.selectFork(fork);

//         deployer = new DeployMeme();
//         meme = deployer.run();

//         routerAddress = vm.envAddress("BASE_SWAP_ROUTER");
//         wethAddress = vm.envAddress("BASE_WETH_ADDRESS");

//         owner = meme.owner();
//         bob = vm.addr(1);
//         vm.label(bob, "bob");

//         deal(wethAddress, owner, 10_000 ether);
//         vm.deal(address(meme), 10 ether);
//     }

//     function testConstructor() public {
//         assertEq(meme.name(), "LOVE TITS");
//         assertEq(meme.symbol(), "LTS");
//         assertEq(meme.routerAddress(), routerAddress);
//         assertEq(meme.wethAddress(), wethAddress);
//     }

//     modifier hasCreatedPairAndAddedLiquidity() {
//         vm.startPrank(owner);

//         // Approve meme token to spend owner's WETH tokens
//         ERC20(wethAddress).approve(address(meme), 10_000 ether);

//         (uint256 amountA, uint256 amountB, uint256 liquidity) = meme.createLiquidityPair(1000 ether, 1000 ether);
//         // console2.log(amountA, amountB, liquidity);
//         vm.stopPrank();
//         _;
//     }

//     modifier hasBalance(address wallet, uint256 amount) {
//         vm.startPrank(owner);
//         deal(address(meme), wallet, amount);
//         vm.stopPrank();
//         _;
//     }

//     function testWalletCanTransferWithoutPayTax() external hasCreatedPairAndAddedLiquidity hasBalance(bob, 10 ether) {
//         uint256 bobBalance = ERC20(address(meme)).balanceOf(bob);
//         uint256 ownerBalance = ERC20(address(meme)).balanceOf(owner);
//         uint256 amount = 10 ether;

//         vm.startPrank(bob);
//         ERC20(address(meme)).transfer(owner, amount);
//         vm.stopPrank();

//         uint256 bobBalanceEnd = ERC20(address(meme)).balanceOf(bob);
//         uint256 ownerBalanceEnd = ERC20(address(meme)).balanceOf(owner);

//         assertEq(bobBalanceEnd, bobBalance - amount);
//         assertEq(ownerBalanceEnd, ownerBalance + amount);
//     }

//     modifier buyMeme(address wallet, uint256 wethAmount) {
//         IBaseSwapRouter router = IBaseSwapRouter(meme.routerAddress());

//         deal(wethAddress, wallet, wethAmount);

//         address[] memory path = new address[](2);
//         path[0] = wethAddress;
//         path[1] = address(meme);

//         uint256[] memory amountsOut = router.getAmountsOut(wethAmount, path);
//         uint256[] memory amounts = router.swapExactETHForTokens(amountsOut[1], path, bob, block.timestamp);

//         console2.log(amounts[0], amounts[1]);
//         _;
//     }

//     function testTransferChargesTaxWhenBuying() external hasCreatedPairAndAddedLiquidity buyMeme(bob, 10 ether) {
//         // uint256 bobBalance = ERC20(address(meme)).balanceOf(bob);
//         // uint256 amount = 10 ether;

//         // vm.startPrank(meme.routerAddress());
//         // deal(address(meme), meme.routerAddress(), amount);
//         // ERC20(address(meme)).approve(meme.routerAddress(), amount);
//         // ERC20(address(meme)).transfer(bob, amount);
//         // vm.stopPrank();

//         // uint256 bobBalanceEnd = ERC20(address(meme)).balanceOf(bob);
//         // assertEq(bobBalanceEnd, bobBalance - amount);
//     }
// }
