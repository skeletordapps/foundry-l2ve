// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.29;

import {Test} from "forge-std/Test.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {L2VENFTPublic} from "../src/L2VENFTPublic.sol";
import {DeployNFTPublic} from "../script/DeployNFTPublic.s.sol";
import {IL2VENFT} from "../src/interfaces/IL2VENFT.sol";
import {IL2VENFTPhase1} from "../src/interfaces/IL2VENFTPhase1.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

contract L2VENFTPublicTest is Test {
    string public RPC_URL;
    uint256 fork;

    DeployNFTPublic deployer;
    L2VENFTPublic nft;
    IL2VENFTPhase1 l2veNftPhase1;
    uint256 public totalSupplyPhase1 = 5791;

    address phase1;
    address owner;
    address bob;
    address mary;
    address john;
    address charles;

    function setUp() public {
        RPC_URL = vm.envString("BASE_RPC_URL");
        fork = vm.createFork(RPC_URL);
        vm.selectFork(fork);

        deployer = new DeployNFTPublic();
        nft = deployer.run();

        phase1 = nft.l2veNftPhase1();
        l2veNftPhase1 = IL2VENFTPhase1(phase1);

        owner = nft.owner();

        bob = vm.addr(1);
        vm.label(bob, "bob");

        mary = vm.addr(2);
        vm.label(mary, "mary");

        john = vm.addr(3);
        vm.label(john, "john");

        charles = vm.addr(4);
        vm.label(charles, "charles");
    }

    function testConstructor() external {
        assertEq(nft.name(), "L2VE NFT PUBLIC");
        assertEq(nft.symbol(), "L2VEP");
        assertEq(nft.totalSupply(), 0);
        assertEq(nft.overallSupply(), totalSupplyPhase1);
        assertTrue(nft.paused());
    }

    // Owner Functions
    function testCanBlacklist() external {
        vm.startPrank(owner);

        vm.expectEmit(true, true, true, true);
        emit IL2VENFT.WalletBlacklisted(bob);
        nft.addToBlackList(bob);

        vm.stopPrank();

        assertEq(nft.blacklist(bob), true);
    }

    function testCanRemoveFromBlacklist() external {
        vm.startPrank(owner);

        nft.addToBlackList(bob);
        assertEq(nft.blacklist(bob), true);

        vm.warp(block.timestamp + 2 days);

        vm.expectEmit(true, true, true, true);
        emit IL2VENFT.WalletRemovedFromBlacklist(bob);
        nft.removeFromBlacklist(bob);

        vm.stopPrank();

        assertEq(nft.blacklist(bob), false);
    }

    function testRevertInitializeWithZeroValues() external {
        vm.startPrank(owner);

        vm.expectRevert(IL2VENFT.L2VENFT__Cannot_Be_Zero.selector);
        nft.initialize(0);

        vm.stopPrank();
    }

    function testCanInitialize() external {
        vm.startPrank(owner);
        nft.initialize(block.timestamp);
        vm.stopPrank();

        assertFalse(nft.paused());
    }

    modifier initialized() {
        vm.startPrank(owner);
        nft.initialize(block.timestamp);
        vm.stopPrank();
        _;
    }

    function testRevertInitializeWhenInitialized() external initialized {
        vm.startPrank(owner);

        vm.expectRevert(IL2VENFT.L2VENFT__Already_Initialized.selector);
        nft.initialize(block.timestamp);

        vm.stopPrank();
    }

    modifier blacklisted(address wallet) {
        vm.startPrank(owner);
        nft.addToBlackList(wallet);
        vm.stopPrank();
        _;
    }

    function testRevertMintWithWalletBlacklisted() external initialized blacklisted(bob) {
        vm.startPrank(owner);
        vm.expectRevert(IL2VENFT.L2VENFT__Wallet_Blacklisted.selector);
        nft.mint(bob);
        vm.stopPrank();
    }

    function testCanMint() external initialized {
        uint256 supplyExpected = nft.totalSupply() + 5;

        vm.startPrank(bob);
        nft.mint(bob);
        vm.stopPrank();

        assertEq(nft.totalSupply(), supplyExpected);
        assertEq(nft.tokens(bob), 5);
        assertEq(nft.overallSupply(), totalSupplyPhase1 + 5);
    }

    modifier minted(address wallet) {
        vm.startPrank(wallet);
        nft.mint(wallet);
        vm.stopPrank();
        _;
    }

    function testRevertMintWhenAlreadyMinted() external initialized minted(bob) {
        vm.startPrank(bob);
        vm.expectRevert(IL2VENFT.L2VENFT__Minted_Max_Permitted.selector);
        nft.mint(bob);
        vm.stopPrank();
    }

    // function transferTokensIn(address wallet, address token) internal {
    //     uint256 decimals = ERC20(token).decimals();
    //     deal(token, wallet, 69 * 10 ** decimals);
    // }

    // function transferTokensOut(address wallet, address token) internal {
    //     vm.startPrank(wallet);
    //     ERC20(token).transfer(mary, ERC20(token).balanceOf(wallet));
    //     vm.stopPrank();
    // }

    function testCanUpdateBasURI() external {
        string memory expectedBaseURI = "ipfs://foobar/";

        vm.startPrank(owner);
        nft.updatedBaseURI(expectedBaseURI);
        vm.stopPrank();

        assertEq(nft.baseURI(), expectedBaseURI);
    }

    function testRevertMintForTeamWhithZero() external initialized {
        vm.startPrank(owner);
        vm.expectRevert(IL2VENFT.L2VENFT__Cannot_Mint_Zero_Tokens.selector);
        nft.mintForTeam(mary, 0);
        vm.stopPrank();
    }

    function testRevertMintForTeamWhenReachMaxForTx() external initialized {
        vm.startPrank(owner);
        vm.expectRevert(IL2VENFT.L2VENFT__Reached_Max_For_Tx.selector);
        nft.mintForTeam(mary, 11);
        vm.stopPrank();
    }

    function testCanMintForTeam() external initialized {
        uint256 expectedSupply = nft.totalSupply() + 10;
        vm.startPrank(owner);
        nft.mintForTeam(mary, 10);
        vm.stopPrank();

        assertEq(nft.tokens(mary), 10);
        assertEq(nft.totalSupply(), expectedSupply);
        assertEq(nft.overallSupply(), totalSupplyPhase1 + 10);
    }

    function testOwnerCanPause() external initialized {
        assertFalse(nft.paused());

        vm.startPrank(owner);
        nft.pause();
        vm.stopPrank();

        assertTrue(nft.paused());
    }

    function testOwnerCanBurnTokensInBatchesOf250() external initialized minted(bob) {
        assertEq(nft.totalSupply(), 5);

        vm.startPrank(owner);
        nft.burnTokensBatched(john);
        vm.stopPrank();

        assertEq(nft.totalSupply(), 5);
        assertEq(nft.overallSupply(), totalSupplyPhase1 + 5);
        assertEq(nft.totalBurned(), 250);
    }

    function testCanGetNFTInfos() public initialized minted(bob) {
        uint256 nextId = l2veNftPhase1.totalSupply() + 1;
        string memory expectedBaseURI = "ipfs://new_url/";

        vm.startPrank(owner);
        nft.updatedBaseURI(expectedBaseURI);
        vm.stopPrank();

        string memory numberString = Strings.toString(nextId);
        string memory tokenURI = string(abi.encodePacked(numberString, ".json"));

        string memory expectedTokenURI = string(abi.encodePacked(expectedBaseURI, tokenURI));
        string memory currentTokenURI = nft.tokenURI(nextId);

        assertEq(expectedTokenURI, currentTokenURI);
    }
}
