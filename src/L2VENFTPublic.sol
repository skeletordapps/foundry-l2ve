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
import {IL2VENFTPhase1} from "./interfaces/IL2VENFTPhase1.sol";

contract L2VENFTPublic is
    ERC721,
    ERC721Enumerable,
    ERC721URIStorage,
    Pausable,
    Ownable,
    ReentrancyGuard,
    ERC721Burnable
{
    /// ===== 1. Propery Variables =====

    uint256 private _tokenIdCounter;
    uint256 public constant MAX_SUPPLY = 10_000;
    uint256 public constant MAX_PERMITTED = 5;
    ERC20 public immutable L2VE;

    uint256 public startAt;
    uint256 public totalSupplyPhase1;
    uint256 public totalBurned;
    string public baseURI;
    address public l2veNftPhase1;

    mapping(address wallet => uint256 numOfTokens) public tokens;
    mapping(address wallet => bool isBlacklisted) public blacklist;

    modifier whenStarted() {
        if (startAt == 0) revert IL2VENFT.L2VENFT__Not_Initialized();
        _;
    }

    /// ===== 2. Lifecycle Methods =====

    constructor(address _l2ve, address _l2veNft) ERC721("L2VE NFT PUBLIC", "L2VEP") Ownable(msg.sender) {
        L2VE = ERC20(_l2ve);
        baseURI = "ipfs://QmfQVrmH3MwGtbUXUbinphpFBmqKcXGAsb1P2eMCK48xW1/";
        l2veNftPhase1 = _l2veNft;

        uint256 supply = overallSupply();
        totalSupplyPhase1 = supply;
        _tokenIdCounter = supply + 1; // Starts where past contract stopped

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
     */
    function initialize(uint256 _startAt) external onlyOwner nonReentrant {
        if (startAt > 0) revert IL2VENFT.L2VENFT__Already_Initialized();
        if (_startAt == 0) revert IL2VENFT.L2VENFT__Cannot_Be_Zero();

        startAt = _startAt;
        unpause();
    }

    /// ===== 4. Minting Functions =====

    /**
     * @dev Mints a new NFT token to the specified address.
     * - Checks if minting is paused (requires `whenNotPaused` modifier).
     * - Prevents reentrancy attacks (requires `nonReentrant` modifier).
     * - Mints the specified number of tokens and emits a Minted event.
     *
     * Reverts with specific error messages in cases of:
     *   - User already minted in the current round.
     *   - User attempting to mint in round two without having minted in round one.
     *   - Exceeding the maximum supply.
     *
     * @param to The address to which the minted NFT will be assigned.
     */
    function mint(address to) external whenNotPaused whenStarted {
        if (blacklist[to]) revert IL2VENFT.L2VENFT__Wallet_Blacklisted();
        if (tokens[to] == MAX_PERMITTED) revert IL2VENFT.L2VENFT__Minted_Max_Permitted();
        if (overallSupply() + MAX_PERMITTED > MAX_SUPPLY) {
            revert IL2VENFT.L2VENFT__Reached_Max_Supply();
        }

        for (uint256 i = 0; i < MAX_PERMITTED; i++) {
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
    function mintForTeam(address to, uint256 numOfTokens) external onlyOwner whenStarted {
        if (numOfTokens == 0) revert IL2VENFT.L2VENFT__Cannot_Mint_Zero_Tokens();
        if (numOfTokens > 10) revert IL2VENFT.L2VENFT__Reached_Max_For_Tx();
        if (overallSupply() + numOfTokens > MAX_SUPPLY) revert IL2VENFT.L2VENFT__Reached_Max_Supply();

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
        uint256 tokensToBurn = Math.min(batchSize, MAX_SUPPLY - overallSupply());

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

    function overallSupply() public view returns (uint256) {
        return totalSupply() + IL2VENFTPhase1(l2veNftPhase1).totalSupply();
    }
}
