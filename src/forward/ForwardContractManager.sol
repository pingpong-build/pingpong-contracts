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

    uint256 private constant PRICE_EXPIRY = 1 minutes;

    /// @notice Minimum ATH price allowed for purchases
    uint256 public minAthPrice;

    /// @notice Total amount of tokens minted
    uint256 public totalSupply;

    /// @notice Maximum supply cap
    uint256 public immutable maxSupply;

    /// @notice Maturity period in days
    uint256 public immutable maturityDuration;

    /// @notice Price discount percentage (0-100)
    uint256 public immutable priceDiscount;

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

    /* ----------------------- Events ------------------------ */

    /// @notice Emitted when tokens are purchased
    /// @param buyer Address of the buyer
    /// @param paymentToken Address of the payment token (address(0) for ETH)
    /// @param paymentAmount Amount of payment tokens spent (in smallest unit)
    /// @param tokenAmount Amount of tokens received
    /// @param tokenPrice Price of token in payment token
    /// @param athPrice Amount of ath token
    /// @param code Discount code used (empty string if no code used)
    event Purchased(address indexed buyer, address paymentToken, uint256 paymentAmount, uint256 tokenAmount, uint256 tokenPrice, uint256 athPrice, string code);

    /// @notice Emitted when a payment token is configured
    /// @param token The token address being configured
    /// @param minAmount Minimum purchase amount
    /// @param priceFeedId Pyth price feed identifier
    /// @param decimals Token decimal places
    event TokenConfigured( address token, uint256 minAmount, bytes32 priceFeedId, uint8 decimals);

    /* ----------------------- Constructor ------------------------ */

    /// @notice Initialize the contract
    /// @param _uri The base URI for forward contract NFTs
    /// @param _fundCollector Address that will receive payments
    constructor(
        address _pyth,
        string memory _uri,
        address _fundCollector,
        uint256 _maturityDuration,
        uint256 _priceDiscount,
        uint256 _maxSupply,
        uint256 _minAthPrice
    ) ERC1155(_uri) {
        if (_fundCollector == address(0)) revert Errors.InvalidAddress();
        if (_pyth == address(0)) revert Errors.InvalidAddress();
        if (_priceDiscount > 100) revert Errors.InvalidAmount();
        if (_maturityDuration == 0) revert Errors.InvalidAmount();
        if (_maxSupply == 0) revert Errors.InvalidAmount();

        maturityDuration = _maturityDuration;
        priceDiscount = _priceDiscount;
        pyth = IPyth(_pyth);
        fundCollector = _fundCollector;
        maxSupply = _maxSupply;
        minAthPrice = _minAthPrice;

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    /* ----------------------- Admin Functions ------------------------ */

    /// @notice Configure payment token
    /// @param _token Token address (address(0) for ETH)
    /// @param _minAmount Minimum purchase amount in token's smallest unit
    /// @param _priceFeedId Pyth price feed ID
    /// @param _decimals Token decimals
    function setSupportedToken(
        address _token,
        uint256 _minAmount,
        bytes32 _priceFeedId,
        uint8 _decimals
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (_minAmount == 0 || _decimals == 0) revert Errors.InvalidAmount();

        supportedTokens[_token] = SupportedToken({
            minAmount: _minAmount,
            priceFeedId: _priceFeedId,
            decimals: _decimals
        });

        emit TokenConfigured(_token, _minAmount, _priceFeedId, _decimals);
    }

    /* ----------------------- Core Functions ------------------------ */

    /// @notice Fetches current price from Pyth oracle
    /// @dev Returns token price based on Pyth price feed
    /// @param id Pyth price feed ID
    /// @return Price normalized to 18 decimal places
    function getPrice(bytes32 id) public view returns (uint256) {
        PythStructs.Price memory price = pyth.getPriceNoOlderThan(id, PRICE_EXPIRY);
        uint256 price18Decimals = (uint(uint64(price.price)) * Constants.WAD) / (10 ** uint8(uint32(-1 * price.expo)));

        return price18Decimals;
    }

    /// @notice Updates price data from Pyth oracle
    /// @param updateData Price update data from Pyth
    function updatePrice(bytes[] calldata updateData) private {
        uint256 fee = pyth.getUpdateFee(updateData);
        pyth.updatePriceFeeds{value: fee}(updateData);
    }

    /// @notice Purchases tokens with the specified payment token
    /// @param _amount Amount of payment token to spend
    /// @param _token Payment token address (address(0) for ETH)
    /// @param _tokenPriceUpdate Price update data for payment token
    /// @param _code Optional discount code
    function buy(
        uint256 _amount,
        address _token,
        bytes[] calldata _tokenPriceUpdate,
        string calldata _code
    ) external payable nonReentrant {
        SupportedToken memory config = supportedTokens[_token];
        if (config.minAmount == 0) revert Errors.TokenNotSupported();
        if (_amount < config.minAmount) revert Errors.InvalidAmount();

        if (_token == address(0)) {
            if (msg.value < _amount) revert Errors.InsufficientBalance();
            (bool success, ) = fundCollector.call{value: _amount}("");
            if (!success) revert Errors.TransferFailed();
            if (msg.value > _amount) {
                (bool refundSuccess, ) = msg.sender.call{value: msg.value - _amount}("");
                if (!refundSuccess) revert Errors.TransferFailed();
            }
        } else {
            bool success = IERC20(_token).transferFrom(msg.sender, fundCollector, _amount);
            if (!success) revert Errors.TransferFailed();
        }

        updatePrice(_tokenPriceUpdate);

        uint256 tokenPrice = getPrice(config.priceFeedId);
        uint256 usdValue = (_amount * tokenPrice) / (10 ** config.decimals);

        uint256 athPrice = getPrice(Constants.PYTH_ATH_PRICE_FEED_ID);
        if (athPrice < minAthPrice) revert Errors.PriceTooLow();
        athPrice = athPrice * (100 - priceDiscount) / 100;
        uint256 mintAmount = usdValue / athPrice;

        if (mintAmount == 0) revert Errors.InvalidAmount();
        if (totalSupply + mintAmount > maxSupply) revert Errors.MaxSupplyReached();

        totalSupply += mintAmount;

        uint256 currentTokenId = getCurrentTokenId();
        _mint(msg.sender, currentTokenId, mintAmount, "");

        emit Purchased(msg.sender, _token, _amount, mintAmount, tokenPrice, athPrice, _code);
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

    function supportsInterface(bytes4 interfaceId) public view override(ERC1155, AccessControl) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    /// @notice Allow the contract to receive ETH
    receive() external payable {}
}
