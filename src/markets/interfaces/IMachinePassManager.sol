// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

interface IMachinePassManager {
    struct PassType {
        uint256 duration; // in seconds
        mapping(address => uint256) prices; // Mapping of token address to price
    }

    /**
      * @dev Thrown when transfer failed
     */
    error TransferFailed();

    /**
     * @dev Thrown when pass type is wrong
     */
    error InvalidPassType();

    /**
     * @dev Thrown when pass price token is wrong
     */
    error InvalidPassPriceToken();

    /**
     * @dev Thrown when to address is empty
     */
    error InvalidToAddress();

    event PassMinted(address to, uint256 tokenId, uint256 typeId, address token);

    event TypeUpdated(uint256 typeId, uint256 duration, address token, uint256 price);

    function getPassDuration(uint256 tokenId) external returns (uint256);

    function getPassPrice(uint256 typeId, address token) external returns (uint256);

    function mint(address to, uint256 typeId, address token) external returns (uint256);
}
