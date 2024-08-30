// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {ERC1155} from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";

/// @title MiningPassFactory
/// @notice This contract manages the minting and management of mining revenue pass NFTs
/// @dev Inherits from Ownable and ERC1155
contract MiningPassFactory is ERC1155, AccessControl, ReentrancyGuard {
    using Strings for uint256;

    /* ----------------------- Constants ------------------------ */

    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");

    /* ----------------------- Storage ------------------------ */

    /// @notice Struct to store information about each revenue round
    struct Round {
        uint256 roundType;        // Type of the round
        uint256 totalPasses;      // Total number of passes available in this round
        uint256 pricePerPass;     // Price per pass in USDT
        uint256 startTime;        // Start time of the round
        uint256 endTime;          // End time of the round
        uint256 whitelistEndTime; // End time for whitelist minting
        mapping(address => bool) whitelist; // Whitelist of addresses
        mapping(address => uint256) discountList; // Discount list of addresses with their discount rates
        uint256 mintedCount;      // Number of passes minted in this round
        uint256 miningDays;       // The number of days for which this round's revenue is allocated
    }

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
    event RoundCreated(uint256 indexed roundId, uint256 roundType, uint256 startTime, uint256 endTime, uint256 totalPasses, uint256 pricePerPass, uint256 miningDays);

    /// @notice Emitted when a pass is minted
    event PassMinted(uint256 indexed roundId, address indexed buyer, uint256 quantity);

    /// @notice Emitted when addresses are added to the whitelist for a round
    event WhitelistUpdated(uint256 indexed roundId, address[] addresses);

    /// @notice Emitted when discount list is updated for a round
    event DiscountListUpdated(uint256 indexed roundId, address[] addresses, uint256[] discountRates);


    /* ----------------------- Errors ------------------------ */

    /// @notice Error thrown when round time parameters are invalid
    error InvalidRoundTime();

    /// @notice Error thrown when an invalid address is provided
    error InvalidAddress();

    /// @notice Error thrown when trying to mint more passes than available
    error InsufficientPasses();

    /// @notice Error thrown when minting is not active
    error MintingNotActive();

    /// @notice Error thrown when a non-whitelisted address tries to mint during whitelist period
    error NotInWhitelist();

    /// @notice Error thrown when ERC20 transfer fails
    error ERC20TransferFailed();

    /// @notice Error thrown when an invalid discount rate is provided
    error InvalidDiscountRate();

    /// @notice Error thrown when an invalid discount list is provided
    error InvalidDiscountList();

    /* ----------------------- Constructor ------------------------ */

    /// @notice Initializes the contract with USDT token address and revenue collector address
    /// @param _usdtToken Address of the USDT token contract
    /// @param _fundCollector Address to collect the revenue
    constructor(address _usdtToken, address _fundCollector, string memory _uri) ERC1155(_uri) {
        if (_usdtToken == address(0) || _fundCollector == address(0)) {
            revert InvalidAddress();
        }

        usdtToken = IERC20(_usdtToken);
        fundCollector = _fundCollector;

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(OPERATOR_ROLE, msg.sender);
    }

    /* ----------------------- Admin functions ------------------------ */

    /// @notice Create a new round
    /// @param _totalPasses Total number of passes for this round
    /// @param _pricePerPass Price per pass in USDT
    /// @param _startTime Start time of the round
    /// @param _endTime End time of the round
    /// @param _whitelistEndTime End time for whitelist minting
    /// @param _miningDays The number of days for which this round's revenue is allocated
    function createRound(
        uint256 _roundType,
        uint256 _totalPasses,
        uint256 _pricePerPass,
        uint256 _startTime,
        uint256 _endTime,
        uint256 _whitelistEndTime,
        uint256 _miningDays
    ) external onlyRole(OPERATOR_ROLE) {
        if (_startTime >= _endTime) {
            revert InvalidRoundTime();
        }

        if (_endTime <= block.timestamp) {
            revert InvalidRoundTime();
        }

        if (_whitelistEndTime < _startTime || _whitelistEndTime > _endTime) {
            revert InvalidRoundTime();
        }

        roundCount++;
        Round storage newRound = rounds[roundCount];
        newRound.roundType = _roundType;
        newRound.startTime = _startTime;
        newRound.endTime = _endTime;
        newRound.totalPasses = _totalPasses;
        newRound.pricePerPass = _pricePerPass;
        newRound.whitelistEndTime = _whitelistEndTime;
        newRound.miningDays = _miningDays;

        emit RoundCreated(roundCount, _roundType, _startTime, _endTime, _totalPasses, _pricePerPass, _miningDays);
    }

    /// @notice Set the whitelist for a specific round
    /// @param _roundId The ID of the round
    /// @param _addresses Array of addresses to be whitelisted
    function setWhitelist(uint256 _roundId, address[] calldata _addresses) external onlyRole(OPERATOR_ROLE) {
        Round storage round = rounds[_roundId];
        for (uint256 i = 0; i < _addresses.length; i++) {
            round.whitelist[_addresses[i]] = true;
        }

        emit WhitelistUpdated(_roundId, _addresses);
    }

    /// @notice Set the discount list for a specific round
    /// @param _roundId The ID of the round
    /// @param _addresses Array of addresses to be added to the discount list
    /// @param _discountRates Array of corresponding discount rates (100 means no discount, 50 means 50% discount)
    function setDiscountList(uint256 _roundId, address[] calldata _addresses, uint256[] calldata _discountRates) external onlyRole(OPERATOR_ROLE) {
        if (_addresses.length != _discountRates.length) {
            revert InvalidDiscountList();
        }

        Round storage round = rounds[_roundId];

        for (uint256 i = 0; i < _addresses.length; i++) {
            if (_discountRates[i] > 100) revert InvalidDiscountRate();
            round.discountList[_addresses[i]] = _discountRates[i];
        }

        emit DiscountListUpdated(_roundId, _addresses, _discountRates);
    }

    /// @notice Mint mining-pass for a specific round
    /// @param _roundId The ID of the round
    /// @param _quantity The number of pass to mint
    function mint(uint256 _roundId, uint256 _quantity) external nonReentrant {
        Round storage round = rounds[_roundId];
        if (block.timestamp < round.startTime || block.timestamp > round.endTime) {
            revert MintingNotActive();
        }

        if (round.mintedCount + _quantity > round.totalPasses) {
            revert InsufficientPasses();
        }

        if (block.timestamp <= round.whitelistEndTime) {
            if (!round.whitelist[msg.sender]) {
                revert NotInWhitelist();
            }
        }

        uint256 discountRate = round.discountList[msg.sender];
        uint256 totalCost = round.pricePerPass * _quantity * (100 - discountRate) / 100;

        bool success = usdtToken.transferFrom(msg.sender, fundCollector, totalCost);
        if (!success) {
            revert ERC20TransferFailed();
        }

        _mint(msg.sender, _roundId, _quantity, "");
        round.mintedCount += _quantity;

        emit PassMinted(_roundId, msg.sender, _quantity);
    }

    /* ----------------------- View functions ------------------------ */

    /// @notice Get token URI of mining-pass
    /// @param _tokenId The pass NFT token id
    /// @return The token URI
    function uri(uint256 _tokenId) public view virtual override returns (string memory) {
        return string(abi.encodePacked(super.uri(_tokenId), _tokenId.toString()));
    }

    function supportsInterface(bytes4 interfaceId) public view override(ERC1155, AccessControl) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}
