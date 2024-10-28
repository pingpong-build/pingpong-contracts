// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IYieldPassManager} from "../interfaces/IYieldPassManager.sol";
import {Errors} from "../libraries/Errors.sol";
import {Constants} from "../libraries/Constants.sol";

/// @title MultiMiningYieldV2
/// @notice Manages the sale of yield passes with support for multiple payment tokens
contract MultiMiningYieldV2 is AccessControl, ReentrancyGuard {

    /* ----------------------- Storage ------------------------ */

    /// @notice The YieldPassManager contract
    IYieldPassManager public immutable yieldPassManager;

    /// @notice Address that receives all payments
    address public fundCollector;

    /// @notice The fixed round ID for this sale contract
    uint256 public immutable roundId;

    /// @notice Mapping of payment token address to price per pass
    mapping(address => uint256) public supportedTokens;

    /// @notice Mapping of discount code hash to discount percentage in basis points
    mapping(bytes32 => uint256) public discountCodes;

    /* ----------------------- Events ------------------------ */

    event TokenPriceUpdated(address token, uint256 price);
    event MultiMiningYieldMinted(
        address buyer,
        uint256 quantity,
        address paymentToken,
        uint256 totalPrice
    );
    event DiscountCodeUpdated(bytes32 indexed code, uint256 discount);

    /* ----------------------- Errors ------------------------ */

    error InvalidDiscountCode();
    error InvalidDiscount();

    /* ----------------------- Constructor ------------------------ */

    /// @notice Initialize the contract with the pass manager, fund collector and round ID
    /// @param _yieldPassManager Address of the YieldPassManager contract
    /// @param _fundCollector Address that will receive payments
    /// @param _roundId The fixed round ID for this sale contract
    constructor(
        address _yieldPassManager,
        address _fundCollector,
        uint256 _roundId
    ) {
        if (_yieldPassManager == address(0) || _fundCollector == address(0)) revert Errors.InvalidAddress();

        yieldPassManager = IYieldPassManager(_yieldPassManager);
        fundCollector = _fundCollector;
        roundId = _roundId;

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(Constants.OPERATOR_ROLE, msg.sender);
    }

    /* ----------------------- Admin Functions ------------------------ */

    /// @notice Set or update price for a payment token (including ETH)
    /// @param token Address of the payment token (address(0) for ETH)
    /// @param price Price per pass in the token's smallest unit (0 to disable)
    function setTokenPrice(
        address token,
        uint256 price
    ) external onlyRole(Constants.OPERATOR_ROLE) {
        supportedTokens[token] = price;
        emit TokenPriceUpdated(token, price);
    }

    /// @notice Set or update multiple discount codes at once
    /// @param codes Array of discount codes
    /// @param discounts Array of discount percentages in basis points
    function setDiscountCodes(
        string[] calldata codes,
        uint256[] calldata discounts
    ) external onlyRole(Constants.OPERATOR_ROLE) {
        if (codes.length != discounts.length) revert Errors.InvalidArrayLength();
        if (codes.length == 0) revert InvalidDiscountCode();

        for (uint256 i = 0; i < codes.length; i++) {
            if (discounts[i] > 100) revert InvalidDiscount();
            if (bytes(codes[i]).length == 0) revert InvalidDiscountCode();

            bytes32 codeHash = keccak256(abi.encodePacked(codes[i]));
            discountCodes[codeHash] = discounts[i];

            emit DiscountCodeUpdated(codeHash, discounts[i]);
        }
    }

    /* ----------------------- External Functions ------------------------ */

    /// @notice Mint passes with either ETH or ERC20 tokens
    /// @param quantity Number of passes to purchase
    /// @param token Address of the payment token (address(0) for ETH)
    function mint(uint256 quantity, address token, string calldata code) external payable nonReentrant {
        uint256 price = supportedTokens[token];
        if (price == 0) revert Errors.TokenNotSupported();

        bytes32 codeHash = keccak256(abi.encodePacked(code));
        uint256 discount = discountCodes[codeHash];
        uint256 totalPrice = price * quantity * (100 - discount) / 100;

        if (token == address(0)) {
            if (msg.value < totalPrice) revert Errors.InsufficientBalance();

            (bool success, ) = fundCollector.call{value: totalPrice}("");
            if (!success) revert Errors.TransferFailed();

            if (msg.value > totalPrice) {
                (success, ) = msg.sender.call{value: msg.value - totalPrice}("");
                if (!success) revert Errors.TransferFailed();
            }
        } else {
            bool success = IERC20(token).transferFrom(msg.sender, fundCollector, totalPrice);
            if (!success) revert Errors.TransferFailed();
        }

        yieldPassManager.mint(roundId, msg.sender, quantity);

        emit MultiMiningYieldMinted(msg.sender, quantity, token, totalPrice);
    }

    /// @notice Allow the contract to receive ETH
    receive() external payable {}
}
