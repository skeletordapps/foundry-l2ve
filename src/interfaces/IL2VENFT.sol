// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

interface IL2VENFT {
    enum Round {
        One,
        Two
    }

    error L2VENFT__Cannot_Be_Zero();
    error L2VENFT__Not_Initialized();
    error L2VENFT__Already_Initialized();
    error L2VENFT__Cannot_Mint_Zero_Tokens();
    error L2VENFT__Reached_Max_Supply();
    error L2VENFT__Reached_Max_For_Tx();
    error L2VENFT__Public_Mint_Round();
    error L2VENFT__RoundOneFinished();
    error L2VENFT__Minted_Max_Permitted();
    error L2VENFT__Wallet_Blacklisted();
    error L2VENFT__Missing_Permitted_Tokens();

    event Created(uint256 maxSupply);
    event Minted(address indexed wallet, uint256 tokenId, string tokenUri);
    event UpdatedBaseURI(address indexed wallet, string newBaseURI);
    event TokensBurned(address indexed wallet, uint256 rangeStart, uint256 rangeEnd);
    event TokensPermitted(address[] permittedTokens);
    event WalletBlacklisted(address indexed wallet);
    event WalletRemovedFromBlacklist(address indexed wallet);
}
