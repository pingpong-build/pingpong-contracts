// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../interfaces/IMerchantController.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import {Constants} from "../libraries/Constants.sol";
import {Errors} from "../libraries/Errors.sol";

/// @title MerchantController
/// @notice Controller for managing forward contracts, handles contract states and parameters
/// @dev Uses AccessControl for permission management, including global operators and per-contract merchants
contract MerchantController is IMerchantController, AccessControl {
    // Prefix for merchant roles, each contract has its own merchant role
    bytes32 public constant MERCHANT_ROLE_PREFIX = keccak256("MERCHANT_ROLE_");

    // @notice Mapping from forward contract address to its configuration
    mapping(address => ForwardContractInfo) private forwardContracts;

    /// @notice Mapping from forward contract to token configurations
    mapping(address => mapping(address => SupportedToken)) private supportedTokens;

    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(Constants.OPERATOR_ROLE, msg.sender);
    }

    /// @notice Ensures caller is either an operator or a merchant of the contract
    modifier canOperate(address forwardContract) {
        if (!hasRole(Constants.OPERATOR_ROLE, msg.sender) &&
        !hasRole(getMerchantRole(forwardContract), msg.sender))
            revert Errors.Unauthorized();
        _;
    }

    /// @notice Ensures the forward contract is active
    modifier onlyActive(address forwardContract) {
        if (!forwardContracts[forwardContract].isActive)
            revert ContractNotActive();
        _;
    }

    /// @notice Calculates the merchant role identifier for a specific contract
    /// @param forwardContract Address of the forward contract
    /// @return bytes32 The role identifier for the contract's merchants
    function getMerchantRole(address forwardContract) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(MERCHANT_ROLE_PREFIX, forwardContract));
    }

    /// @notice Registers a new forward contract and sets up initial configuration
    /// @param forwardContract Address of the forward contract to register
    /// @param merchant Address of the merchant to grant permissions to
    /// @param initialDiscount Initial discount percentage (0-100)
    /// @param initialMaxSupply Initial maximum supply limit
    /// @param initialMinPrice Initial minimum price threshold
    function registerForwardContract(
        address forwardContract,
        address merchant,
        uint256 initialDiscount,
        uint256 initialMaxSupply,
        uint256 initialMinPrice
    ) external onlyRole(Constants.OPERATOR_ROLE) {
        if (forwardContract == address(0) || merchant == address(0)) revert Errors.InvalidAddress();
        if (initialDiscount > 100) revert InvalidDiscount();

        forwardContracts[forwardContract] = ForwardContractInfo({
            isActive: true,
            discount: initialDiscount,
            maxSupply: initialMaxSupply,
            minPrice: initialMinPrice
        });

        _grantRole(getMerchantRole(forwardContract), merchant);

        emit ForwardContractRegistered(forwardContract, merchant, initialDiscount, initialMaxSupply, initialMinPrice);
    }

    /// @notice Updates the active status of a forward contract
    /// @param forwardContract Address of the forward contract
    /// @param isActive New active status
    function updateContractStatus(address forwardContract, bool isActive)
    external
    canOperate(forwardContract)
    {
        forwardContracts[forwardContract].isActive = isActive;
        emit ForwardContractStatusUpdated(forwardContract, isActive, msg.sender);
    }

    /// @notice Updates the forward contract parameters
    /// @param forwardContract Address of the forward contract
    /// @param newDiscount New discount percentage (0-100)
    /// @param newMaxSupply New maximum supply limit
    /// @param newMinPrice New minimum price threshold
    function updateForwardContract(
        address forwardContract,
        uint256 newDiscount,
        uint256 newMaxSupply,
        uint256 newMinPrice
    )
    external
    canOperate(forwardContract)
    onlyActive(forwardContract)
    {
        if (newDiscount > 100)
            revert InvalidDiscount();

        ForwardContractInfo storage info = forwardContracts[forwardContract];
        info.discount = newDiscount;
        info.maxSupply = newMaxSupply;
        info.minPrice = newMinPrice;

        emit ForwardContractUpdated(forwardContract, newDiscount, newMaxSupply, newMinPrice);
    }

    /// @notice Configure payment token
    /// @param forwardContract Address of the forward contract
    /// @param token Token address (address(0) for ETH)
    /// @param minAmount Minimum purchase amount in token's smallest unit
    /// @param priceFeedId Pyth price feed ID
    /// @param decimals Token decimals
    function setSupportedToken(
        address forwardContract,
        address token,
        uint256 minAmount,
        bytes32 priceFeedId,
        uint8 decimals
    ) external canOperate(forwardContract) onlyActive(forwardContract) {
        if (decimals == 0) revert Errors.InvalidAmount();

        supportedTokens[forwardContract][token] = SupportedToken({
            minAmount: minAmount,
            priceFeedId: priceFeedId,
            decimals: decimals
        });

        emit SupportedTokenConfigured(forwardContract, token, minAmount, priceFeedId, decimals);
    }


    /// @notice Retrieves the configuration information of a forward contract
    /// @param forwardContract Address of the forward contract
    /// @return Configuration information of the forward contract
    function getForwardContractInfo(address forwardContract) external view returns (ForwardContractInfo memory) {
        return forwardContracts[forwardContract];
    }

    /// @notice Get supported token configuration
    /// @param forwardContract Address of the forward contract
    /// @param token Token address to check (address(0) for ETH)
    /// @return Token configuration information
    function getSupportedToken(address forwardContract, address token) external view returns (SupportedToken memory) {
        return supportedTokens[forwardContract][token];
    }
}
