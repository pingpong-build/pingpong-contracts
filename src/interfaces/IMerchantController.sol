// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @title IMerchantController
/// @notice Interface for forward contracts to interact with merchant controller
interface IMerchantController {
    /// @notice Forward contract configuration info
    /// @param isActive Whether the contract is active
    /// @param discount Discount percentage (0-100)
    /// @param maxSupply Maximum supply limit
    /// @param minPrice Minimum price threshold
    struct ForwardContractInfo {
        bool isActive;
        uint256 discount;
        uint256 maxSupply;
        uint256 minPrice;
    }

    /// @notice Configuration struct for supported payment tokens
    /// @dev Stores configurations for each supported payment token
    struct SupportedToken {
        uint256 minAmount;          // Minimum purchase amount in token's smallest unit
        bytes32 priceFeedId;        // Pyth price feed ID (0 for stablecoins)
        uint8 decimals;             // Token decimals
    }

    /// @notice Retrieves the configuration information of a forward contract
    /// @param forwardContract Address of the forward contract
    /// @return ForwardContractInfo struct
    function getForwardContractInfo(address forwardContract) external view returns (ForwardContractInfo memory);

    /// @notice Get supported token configuration
    /// @param forwardContract Address of the forward contract
    /// @param token Token address to check (address(0) for ETH)
    /// @return SupportedToken struct
    function getSupportedToken(address forwardContract, address token) external view returns (SupportedToken memory);

    // Events
    /// @notice Emitted when a new forward contract is registered
    /// @param forwardContract Address of the registered forward contract
    /// @param merchant Address of the assigned merchant
    /// @param discount Initial discount percentage (0-100)
    /// @param maxSupply Initial maximum supply limit
    /// @param minPrice Initial minimum price threshold
    event ForwardContractRegistered(
        address indexed forwardContract,
        address indexed merchant,
        uint256 discount,
        uint256 maxSupply,
        uint256 minPrice
    );

    /// @notice Emitted when a forward contract's active status is updated
    /// @param forwardContract Address of the forward contract
    /// @param isActive New status of the contract
    /// @param updater Address that performed the update (operator or merchant)
    event ForwardContractStatusUpdated(address forwardContract, bool isActive, address updater);

    /// @notice Emitted when a forward contract's parameters are updated
    /// @param forwardContract Address of the forward contract
    /// @param discount New discount percentage (0-100)
    /// @param maxSupply New maximum supply limit
    /// @param minPrice New minimum price threshold
    event ForwardContractUpdated(address forwardContract, uint256 discount, uint256 maxSupply, uint256 minPrice);

    /// @notice Emitted when a payment token is configured
    /// @param forwardContract The forward contract being configured
    /// @param token The token address being configured
    /// @param minAmount Minimum purchase amount
    /// @param priceFeedId Pyth price feed identifier
    /// @param decimals Token decimal places
    event SupportedTokenConfigured(
        address indexed forwardContract,
        address token,
        uint256 minAmount,
        bytes32 priceFeedId,
        uint8 decimals
    );

    // Custom errors
    error InvalidDiscount();
    error ContractNotActive();
}
