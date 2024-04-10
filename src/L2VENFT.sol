// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {ERC721Enumerable} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import {ERC721URIStorage} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import {ERC721Burnable} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {console2} from "forge-std/Test.sol";

import {IL2VENFT} from "./interfaces/IL2VENFT.sol";

/**
 * @dev Main contract for L2VE NFTs
 * MIN_AMOUNT_HOLD is internally accounted with correct token's decimals
 */
contract L2VENFT is ERC721, ERC721Enumerable, ERC721URIStorage, Pausable, Ownable, ReentrancyGuard, ERC721Burnable {
    /// ===== 1. Propery Variables =====

    uint256 private _tokenIdCounter;
    uint256 public constant MIN_AMOUNT_HOLD = 69;
    uint256 public constant MAX_SUPPLY = 10_000;
    ERC20 public immutable L2VE;

    uint256 public roundOneFinishAt;
    uint256 public roundTwoFinishAt;
    uint256 public totalBurned;
    string public baseURI;

    ERC20[] public permittedTokens;

    mapping(address wallet => mapping(IL2VENFT.Round round => uint256 numOfTokens)) tokensByRound;
    mapping(address wallet => uint256 numOfTokens) public tokens;
    mapping(address wallet => bool isBlacklisted) public blacklist;

    /// ===== 2. Lifecycle Methods =====

    constructor(address _l2ve) ERC721("L2VE NFT", "L2VE") Ownable(msg.sender) {
        L2VE = ERC20(_l2ve);
        baseURI = "ipfs://Qmc1jomFCj4pcw95EuW3o5Pp7ERsL8qEcKNrDEi7iiQRsT/"; // Set initial baseURI
        _tokenIdCounter++; // Start token ID at 1
        pause(); // Initialize it as paused

        emit IL2VENFT.Created(MAX_SUPPLY);
    }

    /// ===== 3. Pauseable Functions =====

    /**
     * @dev Pauses all token transfers.
     * Can only be called by the contract owner.
     */
    function pause() public onlyOwner {
        _pause();
    }

    /**
     * @dev Unpauses token transfers.
     * Can only be called by the contract owner.
     */
    function unpause() public onlyOwner {
        _unpause();
    }

    /**
     * @dev Adds an address to the blacklist, preventing them from minting NFTs.
     * Can only be called by the contract owner.
     * @param wallet The address to blacklist.
     */
    function addToBlackList(address wallet) external onlyOwner nonReentrant {
        blacklist[wallet] = true;
        emit IL2VENFT.WalletBlacklisted(wallet);
    }

    /**
     * @dev Removes an address from the blacklist, allowing them to mint NFTs again.
     * Can only be called by the contract owner.
     * @param wallet The address to remove from the blacklist.
     */
    function removeFromBlacklist(address wallet) external onlyOwner nonReentrant {
        blacklist[wallet] = false;
        emit IL2VENFT.WalletRemovedFromBlacklist(wallet);
    }

    /**
     * @dev Initializes the contract with timestamps for round endings.
     * Can only be called by the contract owner.
     * @param _roundOneFinishAt The timestamp representing the end of round one.
     * @param _roundTwoFinishAt The timestamp representing the end of round two.
     */
    function initialize(uint256 _roundOneFinishAt, uint256 _roundTwoFinishAt) external onlyOwner nonReentrant {
        if (permittedTokens.length == 0) revert IL2VENFT.L2VENFT__Missing_Permitted_Tokens();
        roundOneFinishAt = _roundOneFinishAt;
        roundTwoFinishAt = _roundTwoFinishAt;
        unpause();
    }

    /// ===== 4. Minting Functions =====

    /**
     * @dev Mints a new NFT token to the specified address.
     * - Checks if minting is paused (requires `whenNotPaused` modifier).
     * - Prevents reentrancy attacks (requires `nonReentrant` modifier).
     * - Determines the current round (roundOne or roundTwo) based on timestamps.
     * - Verifies eligibility for minting based on round and user's holdings.
     * - Mints the specified number of tokens and emits a Minted event.
     *
     * Reverts with specific error messages in cases of:
     *   - User already minted in the current round.
     *   - User attempting to mint in round two without having minted in round one.
     *   - Exceeding the maximum supply.
     *
     * @param to The address to which the minted NFT will be assigned.
     */
    function mint(address to) external whenNotPaused {
        if (blacklist[to]) revert IL2VENFT.L2VENFT__Wallet_Blacklisted();

        bool isRoundOne = block.timestamp <= roundOneFinishAt;
        bool mintedInRoundOne = tokensByRound[to][IL2VENFT.Round.One] > 0;
        bool mintedInRoundTwo = tokensByRound[to][IL2VENFT.Round.Two] > 0;

        if (isRoundOne && mintedInRoundOne) revert IL2VENFT.L2VENFT__Minted_Max_Permitted();
        if (!isRoundOne && mintedInRoundTwo) revert IL2VENFT.L2VENFT__Minted_Max_Permitted();

        uint256 tokensToMint;

        if (isRoundOne && isL2VEHolder(to)) tokensToMint = 5;
        if (isRoundOne && isCommunityHolder(to)) tokensToMint = 2;
        if (!isRoundOne && mintedInRoundOne) tokensToMint = 2;

        if (totalSupply() + tokensToMint > MAX_SUPPLY) revert IL2VENFT.L2VENFT__Reached_Max_Supply();

        for (uint256 i = 0; i < tokensToMint; i++) {
            _mint(to);
        }
    }

    /**
     * @dev Mints a specified number of NFTs for the team wallet.
     * Can only be called by the contract owner.
     *
     * @param to The address to mint tokens to (usually the team wallet).
     * @param numOfTokens The number of NFTs to mint.
     *
     * Emits no event.
     */
    function mintForTeam(address to, uint256 numOfTokens) external onlyOwner {
        if (numOfTokens == 0) revert IL2VENFT.L2VENFT__Cannot_Mint_Zero_Tokens();
        if (numOfTokens > 10) revert IL2VENFT.L2VENFT__Reached_Max_For_Tx();
        if (totalSupply() + numOfTokens > MAX_SUPPLY) revert IL2VENFT.L2VENFT__Reached_Max_Supply();

        for (uint256 i = 0; i < numOfTokens; i++) {
            _mint(to);
        }
    }

    /**
     * @dev Internal function to mint a new token and assign it to the specified address.
     * Increments the token ID counter and sets the token URI.
     * Emits a Minted event on successful minting.
     * @param to The address to which the minted token will be assigned.
     */
    function _mint(address to) private nonReentrant {
        uint256 tokenId = _tokenIdCounter;
        _tokenIdCounter++;

        tokens[to]++; // increase wallet mints counter
        tokensByRound[to][currentRound()]++; // increase internal wallet mints counter

        string memory tokenUri = _generateTokenURI(tokenId);
        _safeMint(to, tokenId);
        _setTokenURI(tokenId, tokenUri);

        emit IL2VENFT.Minted(to, tokenId, tokenUri);
    }

    /// ===== 5. Other Functions =====

    /**
     * @dev Updates the base URI for the token metadata.
     * Can only be called by the contract owner.
     * @param _newBaseURI The new base URI for the token metadata.
     */
    function updatedBaseURI(string memory _newBaseURI) external onlyOwner nonReentrant {
        baseURI = _newBaseURI;
        emit IL2VENFT.UpdatedBaseURI(owner(), _newBaseURI);
    }

    /**
     * @dev Burns a range of tokens starting from a specified tokenId.
     * Can only be called by the contract owner.
     * @param to The wallet to mint tokens
     */
    function burnTokensBatched(address to) external onlyOwner nonReentrant {
        uint256 startId = _tokenIdCounter;
        uint256 batchSize = 250;

        // Calculate tokens to burn (capped by remaining supply)
        uint256 tokensToBurn = Math.min(batchSize, MAX_SUPPLY - totalSupply());

        for (uint256 i = 0; i < tokensToBurn; i++) {
            uint256 tokenId = _tokenIdCounter;

            string memory tokenUri = _generateTokenURI(tokenId);
            _safeMint(to, tokenId);
            _setTokenURI(tokenId, tokenUri);
            _burn(startId + i);

            _tokenIdCounter++;
            totalBurned += 1;
        }

        emit IL2VENFT.TokensBurned(to, startId, startId + tokensToBurn - 1);
    }

    /**
     * @dev Adds permitted token contracts to the list of accepted tokens for minting eligibility.
     * Can only be called by the contract owner.
     * @param _permittedTokens An array of addresses for the permitted token contracts.
     */
    function addPermittedTokens(address[] calldata _permittedTokens) external onlyOwner nonReentrant {
        for (uint256 i = 0; i < _permittedTokens.length; i++) {
            permittedTokens.push(ERC20(_permittedTokens[i]));
        }

        emit IL2VENFT.TokensPermitted(_permittedTokens);
    }

    /// INTERNAL FUNCTIONS

    /**
     * @dev Internal function to generate the token URI based on the token ID.
     * @param tokenId The ID of the token.
     * @return The generated token URI.
     */
    function _generateTokenURI(uint256 tokenId) internal pure returns (string memory) {
        string memory tokenIdStr = Strings.toString(tokenId);
        string memory tokenUri = string(abi.encodePacked(tokenIdStr, ".json"));
        return tokenUri;
    }

    /// ===== 6. Overrinding Functions

    /**
     * @dev Returns the base URI for the token metadata.
     * @return The base URI.
     */
    function _baseURI() internal view override returns (string memory) {
        return baseURI;
    }

    function _increaseBalance(address account, uint128 amount) internal virtual override(ERC721, ERC721Enumerable) {}

    function _update(address to, uint256 tokenId, address auth)
        internal
        virtual
        override(ERC721, ERC721Enumerable)
        returns (address)
    {
        return super._update(to, tokenId, auth); // Call the parent implementation if needed
    }

    /// PUBLIC FUNCTIONS

    /**
     * @dev Returns the token URI for a given token ID.
     * Overrides the inherited tokenURI function.
     * @param tokenId The ID of the token.
     * @return The token URI.
     */
    function tokenURI(uint256 tokenId) public view override(ERC721, ERC721URIStorage) returns (string memory) {
        return super.tokenURI(tokenId);
    }

    /**
     * @dev Checks if a given contract interface is supported.
     * Overrides the inherited supportsInterface function.
     * @param interfaceId The interface ID to check.
     * @return A boolean indicating whether the interface is supported.
     */
    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721Enumerable, ERC721URIStorage)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    /**
     * @dev Checks if a given address holds the minimum required amount of L2VE tokens.
     * Used to determine eligibility for minting during specific rounds.
     * @param wallet The address to check for L2VE token holdings.
     * @return True if the address holds at least MIN_AMOUNT_HOLD L2VE tokens, False otherwise.
     */
    function isL2VEHolder(address wallet) public view returns (bool) {
        return L2VE.balanceOf(wallet) >= MIN_AMOUNT_HOLD * 1e18;
    }

    /**
     * @dev Checks if a given address holds a minimum amount of any of the permitted tokens.
     * Used to determine eligibility for minting during specific rounds.
     * @param wallet The address to check for permitted token holdings.
     * @return True if the address holds a sufficient balance in any permitted token, False otherwise.
     */
    function isCommunityHolder(address wallet) public view returns (bool) {
        bool hasBalance;

        for (uint256 i = 0; i < permittedTokens.length; i++) {
            uint256 decimals = permittedTokens[i].decimals();

            if (permittedTokens[i].balanceOf(wallet) >= MIN_AMOUNT_HOLD * 10 ** decimals) {
                hasBalance = true;
                break;
            }
        }

        return hasBalance;
    }

    /**
     * @dev Returns an array containing the addresses of all currently permitted tokens.
     * This allows users and applications to retrieve the list of accepted tokens for minting eligibility.
     * @return An array of addresses representing the permitted token contracts.
     */
    function getPermittedTokens() public view returns (address[] memory) {
        address[] memory permittedTokensAddresses = new address[](permittedTokens.length);
        for (uint256 i = 0; i < permittedTokens.length; i++) {
            permittedTokensAddresses[i] = address(permittedTokens[i]);
        }

        return permittedTokensAddresses;
    }

    /**
     * @dev Determines if an address is eligible to mint during round one.
     * Eligibility is based on holding a minimum amount of L2VE or any of the permitted tokens.
     * @param wallet The address to check for eligibility.
     * @return True if the address is eligible for round one minting, False otherwise.
     */
    function isEligibleForRoundOne(address wallet) public view returns (bool) {
        if (isL2VEHolder(wallet)) return true;
        if (isCommunityHolder(wallet)) return true;

        return false;
    }

    /**
     * @dev Determines if an address is eligible to mint during round two.
     * Eligibility in round two is restricted to users who minted at least once in round one.
     * @param wallet The address to check for eligibility.
     * @return True if the address is eligible for round two minting, False otherwise.
     */
    function isEligibleForRoundTwo(address wallet) public view returns (bool) {
        return tokensByRound[wallet][IL2VENFT.Round.One] > 0;
    }

    /**
     * @dev Determines the current minting round based on the pre-defined timestamps.
     * @return IL2VENFT.Round.One if the current block timestamp is less than or equal to roundOneFinishAt,
     * indicating round one is active. Otherwise, returns IL2VENFT.Round.Two.
     */
    function currentRound() public view returns (IL2VENFT.Round) {
        return block.timestamp <= roundOneFinishAt ? IL2VENFT.Round.One : IL2VENFT.Round.Two;
    }
}
