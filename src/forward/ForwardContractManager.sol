// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@pythnetwork/pyth-sdk-solidity/IPyth.sol";
import "@pythnetwork/pyth-sdk-solidity/PythStructs.sol";
import {Constants} from "../libraries/Constants.sol";
import {Errors} from "../libraries/Errors.sol";

/// @title ForwardContractManager
/// @notice Manages forward contracts for yield revenue, allowing users to purchase future revenue rights
/// @dev Implements ERC1155 for multi-token management, AccessControl for permissions, and ReentrancyGuard for security
contract ForwardContractManager is ERC1155, AccessControl, ReentrancyGuard {
    using Strings for uint256;

    uint256 private constant PRICE_EXPIRY = 5 minutes;

    /// @notice Instance of the Pyth Oracle interface
    IPyth public immutable pyth;

    /* ----------------------- Storage ------------------------ */

    /// @notice Configuration struct for supported payment tokens
    /// @dev Stores configurations for each supported payment token
    struct SupportedToken {
        uint256 minAmount;          // Minimum purchase amount in token's smallest unit
        bytes32 priceFeedId;        // Pyth price feed ID (0 for stablecoins)
        uint8 decimals;             // Token decimals
    }

    /// @notice Address that receives payments
    address public fundCollector;

    /// @notice Mapping of payment token address to token configuration
    mapping(address => SupportedToken) public supportedTokens;

    /// @notice Mapping of discount code hash to discount percentage
    mapping(bytes32 => uint256) public discountCodes;

    /* ----------------------- Events ------------------------ */

    /// @notice Emitted when tokens are purchased
    /// @param buyer Address of the buyer
    /// @param paymentToken Address of the payment token (address(0) for ETH)
    /// @param paymentAmount Amount of payment tokens spent (in smallest unit)
    /// @param tokenAmount Amount of tokens received
    /// @param code Discount code used (empty string if no code used)
    event Purchased(address indexed buyer, address paymentToken, uint256 paymentAmount, uint256 tokenAmount, string code);

    /// @notice Emitted when a payment token is configured
    /// @param token The token address being configured
    /// @param minAmount Minimum purchase amount
    /// @param priceFeedId Pyth price feed identifier
    /// @param decimals Token decimal places
    event TokenConfigured( address token, uint256 minAmount, bytes32 priceFeedId, uint8 decimals);

    /// @notice Emitted when a discount code is updated
    /// @param code Hash of the discount code
    /// @param discount New discount percentage
    event DiscountCodeUpdated(bytes32 indexed code, uint256 discount);

    /* ----------------------- Constructor ------------------------ */

    /// @notice Initialize the contract
    /// @param _uri The base URI for forward contract NFTs
    /// @param _fundCollector Address that will receive payments
    constructor(address _pyth, string memory _uri, address _fundCollector) ERC1155(_uri) {
        if (_fundCollector == address(0)) revert Errors.InvalidAddress();
        if (_pyth == address(0)) revert Errors.InvalidAddress();

        pyth = IPyth(_pyth);
        fundCollector = _fundCollector;
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(Constants.OPERATOR_ROLE, msg.sender);
    }

    /* ----------------------- Admin Functions ------------------------ */

    /// @notice Configure payment token
    /// @param _token Token address (address(0) for ETH)
    /// @param _minAmount Minimum purchase amount in token's smallest unit
    /// @param _priceFeedId Pyth price feed ID (bytes32(0) for stablecoins)
    /// @param _decimals Token decimals
    function setSupportedToken(
        address _token,
        uint256 _minAmount,
        bytes32 _priceFeedId,
        uint8 _decimals
    ) external onlyRole(Constants.OPERATOR_ROLE) {
        supportedTokens[_token] = SupportedToken({
            minAmount: _minAmount,
            priceFeedId: _priceFeedId,
            decimals: _decimals
        });

        emit TokenConfigured(_token, _minAmount, _priceFeedId, _decimals);
    }

    /// @notice Set multiple discount codes
    /// @param _codes Array of discount codes
    /// @param _discounts Array of discount percentages (1-100)
    function setDiscountCodes(
        string[] calldata _codes,
        uint256[] calldata _discounts
    ) external onlyRole(Constants.OPERATOR_ROLE) {
        if (_codes.length == 0 || _codes.length != _discounts.length) revert Errors.InvalidArrayLength();

        for (uint256 i = 0; i < _codes.length; i++) {
            if (_discounts[i] > 100) revert Errors.InvalidAmount();
            bytes32 codeHash = keccak256(abi.encodePacked(_codes[i]));
            discountCodes[codeHash] = _discounts[i];
            emit DiscountCodeUpdated(codeHash, _discounts[i]);
        }
    }

    /* ----------------------- Core Functions ------------------------ */

    /// @notice Fetches current price from Pyth oracle
    /// @dev Returns WAD (1e18) for stablecoins
    /// @param id Pyth price feed ID
    /// @param pythPriceUpdate Price update data from Pyth
    /// @return Price normalized to 18 decimal places
    function getPrice(bytes32 id, bytes[] calldata pythPriceUpdate) public returns (uint256) {
        if (id == bytes32(0)) return Constants.WAD;

        uint256 fee = pyth.getUpdateFee(pythPriceUpdate);
        pyth.updatePriceFeeds{ value: fee }(pythPriceUpdate);
        PythStructs.Price memory price = pyth.getPriceNoOlderThan(id, PRICE_EXPIRY);
        uint256 price18Decimals = (uint(uint64(price.price)) * Constants.WAD) / (10 ** uint8(uint32(-1 * price.expo)));

        return price18Decimals;
    }

    /// @notice Purchases tokens with the specified payment token
    /// @dev Supports ETH and ERC20 tokens as payment
    /// @param _amount Amount of payment token to spend (in smallest unit)
    /// @param _token Payment token address (address(0) for ETH)
    /// @param _tokenPriceUpdate Pyth price update data for payment token
    /// @param _athPriceUpdate Pyth price update data for output token
    /// @param _code Optional discount code
    function buy(
        uint256 _amount,
        address _token,
        bytes[] calldata _tokenPriceUpdate,
        bytes[] calldata _athPriceUpdate,
        string calldata _code
    ) external payable nonReentrant {
        SupportedToken memory config = supportedTokens[_token];
        if (config.minAmount == 0) revert Errors.TokenNotSupported();
        if (_amount < config.minAmount) revert Errors.InvalidAmount();

        uint256 finalPayment = _amount;
        if (bytes(_code).length > 0) {
            uint256 discount = getDiscount(_code);
            finalPayment = _amount * (100 - discount) / 100;
        }

        if (_token == address(0)) {
            if (msg.value < finalPayment) revert Errors.InsufficientBalance();
            (bool success, ) = fundCollector.call{value: finalPayment}("");
            if (!success) revert Errors.TransferFailed();
            if (msg.value > finalPayment) {
                (bool refundSuccess, ) = msg.sender.call{value: msg.value - finalPayment}("");
                if (!refundSuccess) revert Errors.TransferFailed();
            }
        } else {
            bool success = IERC20(_token).transferFrom(msg.sender, fundCollector, finalPayment);
            if (!success) revert Errors.TransferFailed();
        }

        uint256 tokenPrice = getPrice(config.priceFeedId, _tokenPriceUpdate);
        uint256 usdValue = (_amount * tokenPrice) / (10 ** config.decimals);

        uint256 athPrice = getPrice(Constants.PYTH_ATH_PRICE_FEED_ID, _athPriceUpdate);
        uint256 mintAmount = usdValue / athPrice;

        uint256 currentTokenId = getCurrentTokenId();
        _mint(msg.sender, currentTokenId, mintAmount, "");

        emit Purchased(msg.sender, _token, finalPayment, mintAmount, _code);
    }

    /* ----------------------- View Functions ------------------------ */

    /// @notice Returns token ID for the current day
    /// @dev Uses UTC timestamp for day calculation
    /// @return Current day's token ID
    function getCurrentTokenId() public view returns (uint256) {
        return block.timestamp / 1 days;
    }

    /// @notice Get contract URI
    /// @param _id The forward contract id
    function uri(uint256 _id) public view virtual override returns (string memory) {
        return string(abi.encodePacked(super.uri(_id), _id.toString()));
    }

    /// @notice Get discount percentage for a given code
    /// @param _code Discount code to check
    /// @return Discount percentage (0-100), returns 0 if code is invalid
    function getDiscount(string calldata _code) public view returns (uint256) {
        return discountCodes[keccak256(abi.encodePacked(_code))];
    }

    function supportsInterface(bytes4 interfaceId) public view override(ERC1155, AccessControl) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    /// @notice Allow the contract to receive ETH
    receive() external payable {}
}
