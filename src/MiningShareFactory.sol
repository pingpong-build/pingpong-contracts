// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

/// @title MiningShareFactory
/// @notice This contract manages the minting and management of mining revenue share NFTs
/// @dev Inherits from Ownable and ERC721
contract MiningShareFactory is ERC721, AccessControl {
    using Strings for uint256;

    /* ----------------------- Constants ------------------------ */

    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");

    /* ----------------------- Storage ------------------------ */

    /// @notice Struct to store information about each revenue round
    struct Round {
        uint256 totalShares;      // Total number of shares available in this round
        uint256 pricePerShare;    // Price per share in USDT
        uint256 startTime;        // Start time of the round
        uint256 endTime;          // End time of the round
        uint256 whitelistEndTime; // End time for whitelist minting
        mapping(address => bool) whitelist; // Whitelist of addresses
        uint256 mintedCount;      // Number of shares minted in this round
        uint256 miningDays;       // The number of days for which this round's revenue is allocated
    }

    /// @notice Base URI for computing tokenURI
    string public baseURI;

    /// @notice USDT token contract address
    IERC20 public usdtToken;

    /// @notice Mapping of round ID to RevenueRound struct
    mapping(uint256 => Round) public rounds;

    /// @notice Total number of rounds created
    uint256 public roundCount;

    /// @notice Address to collect the revenue
    address public fundCollector;

    /* ----------------------- Events ------------------------ */

    /// @notice Emitted when a new round is created
    event RoundCreated(uint256 indexed roundId, uint256 startTime, uint256 endTime, uint256 totalShares, uint256 pricePerShare, uint256 miningDays);

    /// @notice Emitted when a share is minted
    event ShareMinted(uint256 indexed roundId, address indexed buyer, uint256 shareId);

    /// @notice Emitted when the revenue collector address is updated
    event FundCollectorUpdated(address newCollector);

    /* ----------------------- Errors ------------------------ */

    /// @notice Error thrown when trying to mint more shares than available
    error InsufficientShares();

    /// @notice Error thrown when minting is not active
    error MintingNotActive();

    /// @notice Error thrown when a non-whitelisted address tries to mint during whitelist period
    error NotInWhitelist();

    /// @notice Error thrown when an invalid share ID is provided
    error InvalidShareId();

    /* ----------------------- Constructor ------------------------ */

    /// @notice Initializes the contract with USDT token address and revenue collector address
    /// @param _usdtToken Address of the USDT token contract
    /// @param _fundCollector Address to collect the revenue
    constructor(address _usdtToken, address _fundCollector) ERC721("Mining Share", "MS") {
        usdtToken = IERC20(_usdtToken);
        fundCollector = _fundCollector;

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(OPERATOR_ROLE, msg.sender);
    }

    /* ----------------------- Admin functions ------------------------ */

    /// @notice Set a new funds collector address
    /// @param _newCollector The address of the new revenue collector
    function setFundCollector(address _newCollector) external onlyRole(DEFAULT_ADMIN_ROLE) {
        fundCollector = _newCollector;
        emit FundCollectorUpdated(_newCollector);
    }

    /// @notice Create a new round
    /// @param _totalShares Total number of shares for this round
    /// @param _pricePerShare Price per share in USDT
    /// @param _startTime Start time of the round
    /// @param _endTime End time of the round
    /// @param _whitelistEndTime End time for whitelist minting
    /// @param _miningDays The number of days for which this round's revenue is allocated
    function createRound(
        uint256 _totalShares,
        uint256 _pricePerShare,
        uint256 _startTime,
        uint256 _endTime,
        uint256 _whitelistEndTime,
        uint256 _miningDays
    ) external onlyRole(OPERATOR_ROLE) {
        roundCount++;
        Round storage newRound = rounds[roundCount];
        newRound.startTime = _startTime;
        newRound.endTime = _endTime;
        newRound.totalShares = _totalShares;
        newRound.pricePerShare = _pricePerShare;
        newRound.whitelistEndTime = _whitelistEndTime;
        newRound.miningDays = _miningDays;

        emit RoundCreated(roundCount, _startTime, _endTime, _totalShares, _pricePerShare, _miningDays);
    }

    /// @notice Set the whitelist for a specific round
    /// @param _roundId The ID of the round
    /// @param _addresses Array of addresses to be whitelisted
    function setWhitelist(uint256 _roundId, address[] calldata _addresses) external onlyRole(OPERATOR_ROLE) {
        Round storage round = rounds[_roundId];
        for (uint256 i = 0; i < _addresses.length; i++) {
            round.whitelist[_addresses[i]] = true;
        }
    }

    /// @notice Set the base URI for computing tokenURI
    /// @param _baseURI The base URI
    function setBaseURI(string memory _baseURI) external onlyRole(OPERATOR_ROLE) {
        baseURI = _baseURI;
    }

    /// @notice Mint a share for a specific round
    /// @param _roundId The ID of the round
    function mint(uint256 _roundId) external {
        _mintShares(_roundId, 1);
    }

    /// @notice Batch mint shares for a specific round
    /// @param _roundId The ID of the round
    /// @param _quantity The number of shares to mint
    function batchMint(uint256 _roundId, uint256 _quantity) external {
        _mintShares(_roundId, _quantity);
    }

    function _mintShares(uint256 _roundId, uint256 _quantity) internal {
        Round storage round = rounds[_roundId];
        if (block.timestamp < round.startTime || block.timestamp > round.endTime) {
            revert MintingNotActive();
        }

        if (round.mintedCount + _quantity > round.totalShares) {
            revert InsufficientShares();
        }

        if (block.timestamp <= round.whitelistEndTime) {
            if (!round.whitelist[msg.sender]) {
                revert NotInWhitelist();
            }
        }

        uint256 totalCost = round.pricePerShare * _quantity;
        usdtToken.transferFrom(msg.sender, fundCollector, totalCost);

        for (uint256 i = 0; i < _quantity; i++) {
            uint256 shareId = ((_roundId - 1) * round.totalShares) + round.mintedCount + i;
            _safeMint(msg.sender, shareId);
            emit ShareMinted(_roundId, msg.sender, shareId);
        }

        round.mintedCount += _quantity;
    }

    /* ----------------------- View functions ------------------------ */

    /// @notice Get the round ID from a share ID
    /// @param _shareId The ID of the share
    /// @return The ID of the round
    function getRoundIdFromShareId(uint256 _shareId) public view returns (uint256) {
        for (uint256 i = 1; i <= roundCount; i++) {
            if (_shareId <= i * rounds[i].totalShares) {
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

    function supportsInterface(bytes4 interfaceId) public view override(ERC721, AccessControl) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}
