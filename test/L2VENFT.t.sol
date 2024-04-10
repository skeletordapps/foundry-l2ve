// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {Test, console2} from "forge-std/Test.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import {L2VENFT} from "../src/L2VENFT.sol";
import {DeployNFT} from "../script/DeployNFT.s.sol";
import {IL2VENFT} from "../src/interfaces/IL2VENFT.sol";

contract L2VENFTTest is Test {
    string public RPC_URL;
    uint256 fork;

    DeployNFT deployer;
    L2VENFT nft;

    address degen = 0x4ed4E862860beD51a9570b96d89aF5E1B0Efefed;
    address normie = 0x7F12d13B34F5F4f0a9449c16Bcd42f0da47AF200;
    address brett = 0x532f27101965dd16442E59d40670FaF5eBB142E4;
    address doginme = 0x6921B130D297cc43754afba22e5EAc0FBf8Db75b;
    address tybg = 0x0d97F261b1e88845184f678e2d1e7a98D9FD38dE;

    address owner;
    address bob;
    address mary;
    address john;

    function setUp() public {
        RPC_URL = vm.envString("BASE_RPC_URL");
        fork = vm.createFork(RPC_URL);
        vm.selectFork(fork);

        deployer = new DeployNFT();
        nft = deployer.run();

        owner = nft.owner();

        bob = vm.addr(1);
        vm.label(bob, "bob");

        mary = vm.addr(2);
        vm.label(mary, "mary");

        john = vm.addr(3);
        vm.label(john, "john");
    }

    function testConstructor() external {
        assertEq(nft.name(), "L2VE NFT");
        assertEq(nft.symbol(), "L2VE");
        assertEq(nft.totalSupply(), 0);
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

    function testRevertInitializeWithoutPermittedTokens() external {
        vm.startPrank(owner);
        vm.expectRevert(IL2VENFT.L2VENFT__Missing_Permitted_Tokens.selector);
        nft.initialize(block.timestamp + 3 days, block.timestamp + 10 days);
        vm.stopPrank();

        assertTrue(nft.paused());
    }

    function testCanAddPermittedTokens() external {
        address[] memory expectedTokens = new address[](5);
        expectedTokens[0] = degen;
        expectedTokens[1] = normie;
        expectedTokens[2] = brett;
        expectedTokens[3] = doginme;
        expectedTokens[4] = tybg;

        vm.startPrank(owner);
        vm.expectEmit(true, true, true, true);
        emit IL2VENFT.TokensPermitted(expectedTokens);
        nft.addPermittedTokens(expectedTokens);
        vm.stopPrank();

        assertEq(nft.getPermittedTokens(), expectedTokens);
    }

    modifier tokensPermitted() {
        address[] memory expectedTokens = new address[](5);
        expectedTokens[0] = degen;
        expectedTokens[1] = normie;
        expectedTokens[2] = brett;
        expectedTokens[3] = doginme;
        expectedTokens[4] = tybg;

        vm.startPrank(owner);
        nft.addPermittedTokens(expectedTokens);
        vm.stopPrank();
        _;
    }

    function testCanInitialize() external tokensPermitted {
        uint256 roundOneFinishAt = block.timestamp + 3 days;
        uint256 roundTwoFinishAt = block.timestamp + 10 days;
        vm.startPrank(owner);
        nft.initialize(roundOneFinishAt, roundTwoFinishAt);
        vm.stopPrank();

        assertFalse(nft.paused());
        assertEq(nft.roundOneFinishAt(), roundOneFinishAt);
        assertEq(nft.roundTwoFinishAt(), roundTwoFinishAt);
    }

    modifier initialized() {
        vm.startPrank(owner);
        nft.initialize(block.timestamp + 3 days, block.timestamp + 10 days);
        vm.stopPrank();
        _;
    }

    modifier roundOneFinished() {
        vm.warp(nft.roundOneFinishAt() + 1 days);
        _;
    }

    modifier roundTwoFinished() {
        vm.warp(nft.roundTwoFinishAt() + 1 days);
        _;
    }

    modifier blacklisted(address wallet) {
        vm.startPrank(owner);
        nft.addToBlackList(wallet);
        vm.stopPrank();
        _;
    }

    function testRevertMintWithWalletBlacklisted() external tokensPermitted initialized blacklisted(bob) {
        vm.startPrank(owner);
        vm.expectRevert(IL2VENFT.L2VENFT__Wallet_Blacklisted.selector);
        nft.mint(bob);
        vm.stopPrank();
    }

    function testIsNotEligibleForRoundOneWithoutL2VEBalance() external {
        deal(address(nft.L2VE()), bob, (nft.MIN_AMOUNT_HOLD() * 1e18) - 1 ether);
        assertFalse(nft.isEligibleForRoundOne(bob));
    }

    function testIsNotEligibleForRoundTwoWhenNotMintedInRoundOne() external {
        assertFalse(nft.isEligibleForRoundTwo(bob));
    }

    function transferTokensIn(address wallet, address token) internal {
        uint256 decimals = ERC20(token).decimals();
        deal(token, wallet, 69 * 10 ** decimals);
    }

    function transferTokensOut(address wallet, address token) internal {
        vm.startPrank(wallet);
        ERC20(token).transfer(mary, ERC20(token).balanceOf(wallet));
        vm.stopPrank();
    }

    function testAllEligibilityScenarios() external tokensPermitted {
        assertFalse(nft.isEligibleForRoundOne(bob));

        address[] memory permittedTokens = nft.getPermittedTokens();

        for (uint256 i = 0; i < permittedTokens.length; i++) {
            transferTokensIn(bob, permittedTokens[i]);
            assertTrue(nft.isEligibleForRoundOne(bob));
            transferTokensOut(bob, permittedTokens[i]);
            assertFalse(nft.isEligibleForRoundOne(bob));
        }
    }

    modifier isLoveHolder() {
        deal(address(nft.L2VE()), bob, nft.MIN_AMOUNT_HOLD() * 1e18);
        assertTrue(nft.isL2VEHolder(bob));
        _;
    }

    function testLoveHolderCanMint5NftsInRoundOne() external tokensPermitted initialized isLoveHolder {
        assertTrue(nft.isEligibleForRoundOne(bob));

        vm.startPrank(bob);
        nft.mint(bob);
        vm.stopPrank();

        assertEq(nft.totalSupply(), 5);
        assertEq(nft.isEligibleForRoundTwo(bob), true);
    }

    modifier loveHolderMinted() {
        vm.startPrank(bob);
        nft.mint(bob);
        vm.stopPrank();
        _;
    }

    function testRevertLoveHolderCannotMintTwiceInRoundOne()
        external
        tokensPermitted
        initialized
        isLoveHolder
        loveHolderMinted
    {
        vm.startPrank(bob);
        vm.expectRevert(IL2VENFT.L2VENFT__Minted_Max_Permitted.selector);
        nft.mint(bob);
        vm.stopPrank();
    }

    modifier isCommunityHolder() {
        address[] memory permittedTokens = nft.getPermittedTokens();
        uint256 decimals = ERC20(permittedTokens[0]).decimals();
        deal(permittedTokens[0], mary, nft.MIN_AMOUNT_HOLD() * 10 ** decimals);
        assertTrue(nft.isCommunityHolder(mary));
        _;
    }

    function testCommunityHolderCanMint2NftsInRoundOne() external tokensPermitted initialized isCommunityHolder {
        assertTrue(nft.isEligibleForRoundOne(mary));

        vm.startPrank(mary);
        nft.mint(mary);
        vm.stopPrank();

        assertEq(nft.totalSupply(), 2);
        assertEq(nft.isEligibleForRoundTwo(mary), true);
    }

    modifier communityHolderMinted() {
        vm.startPrank(mary);
        nft.mint(mary);
        vm.stopPrank();
        _;
    }

    function testRevertCommunityHolderCannotMintTwiceInRoundOne()
        external
        tokensPermitted
        initialized
        isCommunityHolder
        communityHolderMinted
    {
        vm.startPrank(bob);
        vm.expectRevert(IL2VENFT.L2VENFT__Minted_Max_Permitted.selector);
        nft.mint(mary);
        vm.stopPrank();
    }

    function testLoveHolderCanMintInRoundTwo() external tokensPermitted initialized isLoveHolder loveHolderMinted {
        vm.warp(nft.roundOneFinishAt() + 1 days);

        vm.startPrank(bob);
        nft.mint(bob);
        vm.stopPrank();

        assertEq(nft.tokens(bob), 7);
    }

    function testLoveHolderCannotMintAgainInRoundTwo()
        external
        tokensPermitted
        initialized
        isLoveHolder
        loveHolderMinted
    {
        vm.warp(nft.roundOneFinishAt() + 1 days);

        vm.startPrank(bob);
        nft.mint(bob);

        vm.expectRevert(IL2VENFT.L2VENFT__Minted_Max_Permitted.selector);
        nft.mint(bob);
        vm.stopPrank();
    }

    function testCanUpdateBasURI() external {
        string memory expectedBaseURI = "ipfs://foobar/";

        vm.startPrank(owner);
        nft.updatedBaseURI(expectedBaseURI);
        vm.stopPrank();

        assertEq(nft.baseURI(), expectedBaseURI);
    }

    function testRevertMintForTeamWhithZero() external tokensPermitted initialized {
        vm.startPrank(owner);
        vm.expectRevert(IL2VENFT.L2VENFT__Cannot_Mint_Zero_Tokens.selector);
        nft.mintForTeam(mary, 0);
        vm.stopPrank();
    }

    function testRevertMintForTeamWhenReachMaxForTx() external tokensPermitted initialized {
        vm.startPrank(owner);
        vm.expectRevert(IL2VENFT.L2VENFT__Reached_Max_For_Tx.selector);
        nft.mintForTeam(mary, 11);
        vm.stopPrank();
    }

    function testCanMintForTeam() external tokensPermitted initialized {
        vm.startPrank(owner);
        nft.mintForTeam(mary, 10);
        vm.stopPrank();

        assertEq(nft.tokens(mary), 10);
        assertEq(nft.totalSupply(), 10);
    }

    function testOwnerCanPause() external tokensPermitted initialized {
        assertFalse(nft.paused());

        vm.startPrank(owner);
        nft.pause();
        vm.stopPrank();

        assertTrue(nft.paused());
    }

    function testOwnerCanBurnTokensInBatchesOf250()
        external
        tokensPermitted
        initialized
        isLoveHolder
        loveHolderMinted
        isCommunityHolder
        communityHolderMinted
    {
        assertEq(nft.totalSupply(), 7);

        vm.startPrank(owner);
        vm.expectEmit();
        emit IL2VENFT.TokensBurned(john, nft.totalSupply() + 1, nft.totalSupply() + 250);
        nft.burnTokensBatched(john);
        vm.stopPrank();

        assertEq(nft.totalSupply(), 7);
        assertEq(nft.totalBurned(), 250);
    }

    function testCanGetNFTInfos() public tokensPermitted initialized isLoveHolder loveHolderMinted {
        string memory expectedBaseURI = "ipfs://new_url/";

        vm.startPrank(owner);
        nft.updatedBaseURI(expectedBaseURI);
        vm.stopPrank();

        string memory expectedTokenURI = string(abi.encodePacked(expectedBaseURI, "1.json"));
        string memory currentTokenURI = nft.tokenURI(1);

        assertEq(expectedTokenURI, currentTokenURI);
    }
}
