// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@pythnetwork/pyth-sdk-solidity/IPyth.sol";
import "@pythnetwork/pyth-sdk-solidity/PythStructs.sol";
import {Constants} from "../libraries/Constants.sol";
import {Errors} from "../libraries/Errors.sol";
import {IMerchantController} from "../interfaces/IMerchantController.sol";

/// @title ForwardContractManager
/// @notice Manages forward contracts for yield revenue, allowing users to purchase future revenue rights
/// @dev Implements ERC1155 for multi-token management, AccessControl for permissions, and ReentrancyGuard for security
contract ForwardContractManager is ERC1155, ReentrancyGuard {
    using Strings for uint256;

    uint256 private constant PRICE_EXPIRY = 1 minutes;

    /// @notice Total amount of tokens minted
    uint256 public totalSupply;

    /// @notice Instance of the Pyth Oracle interface
    IPyth public immutable pyth;

    /// @notice Instance of the Merchant Controller
    IMerchantController public immutable controller;

    /* ----------------------- Storage ------------------------ */

    /// @notice Address that receives payments
    address public fundCollector;

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

    /* ----------------------- Constructor ------------------------ */

    /// @notice Initialize the contract
    /// @param _uri The base URI for forward contract NFTs
    /// @param _fundCollector Address that will receive payments
    constructor(
        address _controller,
        address _pyth,
        string memory _uri,
        address _fundCollector
    ) ERC1155(_uri) {
        if (_controller == address(0)) revert Errors.InvalidAddress();
        if (_pyth == address(0)) revert Errors.InvalidAddress();
        if (_fundCollector == address(0)) revert Errors.InvalidAddress();

        controller = IMerchantController(_controller);
        pyth = IPyth(_pyth);
        fundCollector = _fundCollector;
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
        IMerchantController.ForwardContractInfo memory contractInfo = controller.getForwardContractInfo(address(this));
        if (!contractInfo.isActive) revert IMerchantController.ContractNotActive();

        IMerchantController.SupportedToken memory tokenConfig = controller.getSupportedToken(address(this), _token);
        if (tokenConfig.minAmount == 0) revert Errors.TokenNotSupported();
        if (_amount < tokenConfig.minAmount) revert Errors.InvalidAmount();

        _handlePayment(_token, _amount);

        updatePrice(_tokenPriceUpdate);

        uint256 tokenPrice = getPrice(tokenConfig.priceFeedId);
        uint256 usdValue = (_amount * tokenPrice) / (10 ** tokenConfig.decimals);

        uint256 athPrice = getPrice(Constants.PYTH_ATH_PRICE_FEED_ID);
        if (athPrice < contractInfo.minPrice) revert Errors.PriceTooLow();
        athPrice = athPrice * (100 - contractInfo.discount) / 100;
        uint256 mintAmount = usdValue / athPrice;

        if (mintAmount == 0) revert Errors.InvalidAmount();
        if (totalSupply + mintAmount > contractInfo.maxSupply) revert Errors.MaxSupplyReached();

        totalSupply += mintAmount;

        uint256 currentTokenId = getCurrentTokenId();
        _mint(msg.sender, currentTokenId, mintAmount, "");

        emit Purchased(msg.sender, _token, _amount, mintAmount, tokenPrice, athPrice, _code);
    }

    /// @notice Handles payment in ETH or ERC20
    /// @param _token Token address (address(0) for ETH)
    /// @param _amount Amount to transfer
    function _handlePayment(address _token, uint256 _amount) private {
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

    /// @notice Allow the contract to receive ETH
    receive() external payable {}
}
