// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

/// @title MiningRevenueShare
/// @notice This contract manages the minting and management of mining revenue share NFTs
/// @dev Inherits from Ownable and ERC721
contract MiningRevenueShare is ERC721, Ownable {
    using Strings for uint256;

    /* ----------------------- Storage ------------------------ */

    /// @notice Struct to store information about each revenue round
    struct RevenueRound {
        uint256 totalShares;      // Total number of shares available in this round
        uint256 pricePerShare;    // Price per share in USDT
        uint256 startTime;        // Start time of the round
        uint256 endTime;          // End time of the round
        uint256 whitelistEndTime; // End time for whitelist minting
        mapping(address => bool) whitelist; // Whitelist of addresses
        uint256 mintedCount;      // Number of shares minted in this round
        uint256 revenueDays;      // The number of days for which this round's revenue is allocated
    }

    /// @notice Base URI for computing tokenURI
    string public baseURI;

    /// @notice USDT token contract address
    IERC20 public usdtToken;

    /// @notice Mapping of round ID to RevenueRound struct
    mapping(uint256 => RevenueRound) public revenueRounds;

    /// @notice Total number of rounds created
    uint256 public roundCount;

    /// @notice Address to collect the revenue
    address public revenueCollector;

    /* ----------------------- Events ------------------------ */

    /// @notice Emitted when a new round is created
    event RoundCreated(uint256 indexed roundId, uint256 totalShares, uint256 pricePerShare, uint256 revenueDays);

    /// @notice Emitted when a share is minted
    event ShareMinted(uint256 indexed roundId, address indexed buyer, uint256 shareId);

    /// @notice Emitted when the revenue collector address is updated
    event RevenueCollectorUpdated(address newCollector);

    /* ----------------------- Errors ------------------------ */

    /// @notice Error thrown when minting is not active
    error MintingNotActive();

    /// @notice Error thrown when all shares have been minted
    error AllSharesMinted();

    /// @notice Error thrown when a non-whitelisted address tries to mint during whitelist period
    error NotInWhitelist();

    /// @notice Error thrown when an invalid share ID is provided
    error InvalidShareId();

    /* ----------------------- Constructor ------------------------ */

    /// @notice Initializes the contract with USDT token address and revenue collector address
    /// @param _usdtToken Address of the USDT token contract
    /// @param _revenueCollector Address to collect the revenue
    constructor(address _usdtToken, address _revenueCollector) ERC721("Mining Revenue Share", "MRS") {
        usdtToken = IERC20(_usdtToken);
        revenueCollector = _revenueCollector;
    }

    /* ----------------------- External functions ------------------------ */

    /// @notice Set a new revenue collector address
    /// @param _newCollector The address of the new revenue collector
    function setRevenueCollector(address _newCollector) external onlyOwner {
        revenueCollector = _newCollector;
        emit RevenueCollectorUpdated(_newCollector);
    }

    /// @notice Create a new revenue round
    /// @param _totalShares Total number of shares for this round
    /// @param _pricePerShare Price per share in USDT
    /// @param _startTime Start time of the round
    /// @param _endTime End time of the round
    /// @param _whitelistEndTime End time for whitelist minting
    /// @param _revenueDays The number of days for which this round's revenue is allocated
    function createRevenueRound(
        uint256 _totalShares,
        uint256 _pricePerShare,
        uint256 _startTime,
        uint256 _endTime,
        uint256 _whitelistEndTime,
        uint256 _revenueDays
    ) external onlyOwner {
        roundCount++;
        RevenueRound storage newRound = revenueRounds[roundCount];
        newRound.totalShares = _totalShares;
        newRound.pricePerShare = _pricePerShare;
        newRound.startTime = _startTime;
        newRound.endTime = _endTime;
        newRound.whitelistEndTime = _whitelistEndTime;
        newRound.revenueDays = _revenueDays;

        emit RoundCreated(roundCount, _totalShares, _pricePerShare, _revenueDays);
    }

    /// @notice Set the whitelist for a specific round
    /// @param _roundId The ID of the round
    /// @param _addresses Array of addresses to be whitelisted
    function setWhitelist(uint256 _roundId, address[] calldata _addresses) external onlyOwner {
        RevenueRound storage round = revenueRounds[_roundId];
        for (uint256 i = 0; i < _addresses.length; i++) {
            round.whitelist[_addresses[i]] = true;
        }
    }

    /// @notice Set the base URI for computing tokenURI
    /// @param _baseURI The base URI
    function setBaseURI(string memory _baseURI) external onlyOwner {
        baseURI = _baseURI;
    }

    /// @notice Mint a share for a specific round
    /// @param _roundId The ID of the round
    function mintShare(uint256 _roundId) external {
        RevenueRound storage round = revenueRounds[_roundId];
        if (block.timestamp < round.startTime || block.timestamp > round.endTime) {
            revert MintingNotActive();
        }
        if (round.mintedCount >= round.totalShares) {
            revert AllSharesMinted();
        }

        if (block.timestamp <= round.whitelistEndTime) {
            if (!round.whitelist[msg.sender]) {
                revert NotInWhitelist();
            }
        }

        usdtToken.transferFrom(msg.sender, revenueCollector, round.pricePerShare);

        uint256 shareId = ((_roundId - 1) * round.totalShares) + round.mintedCount + 1;
        _safeMint(msg.sender, shareId);
        round.mintedCount++;

        emit ShareMinted(_roundId, msg.sender, shareId);
    }

    /* ----------------------- View functions ------------------------ */

    /// @notice Get the round ID from a share ID
    /// @param _shareId The ID of the share
    /// @return The ID of the round
    function getRoundIdFromShareId(uint256 _shareId) public view returns (uint256) {
        for (uint256 i = 1; i <= roundCount; i++) {
            if (_shareId <= i * revenueRounds[i].totalShares) {
                return i;
            }
        }
        revert InvalidShareId();
    }

    /// @notice Get token URI of share NFT
    /// @param tokenId The share NFT token id
    /// @return The token URI
    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        uint256 roundId = getRoundIdFromShareId(tokenId);
        return string.concat(baseURI, roundId.toString());
    }
}
