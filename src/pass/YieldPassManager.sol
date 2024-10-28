// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {ERC1155} from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import {IYieldPassManager} from "../interfaces/IYieldPassManager.sol";
import {Errors} from "../libraries/Errors.sol";
import {Constants} from "../libraries/Constants.sol";

/// @title YieldPassManager
/// @notice This contract manages the minting and management of mining revenue pass NFTs
/// @dev Inherits from AccessControl and ERC1155
contract YieldPassManager is IYieldPassManager, ERC1155, AccessControl, ReentrancyGuard {
    using Strings for uint256;

    /* ----------------------- Storage ------------------------ */

    /// @notice Struct to store information about each revenue round
    struct Round {
        address creator;                    // Address of the creator
        uint256 mintedCount;                // Number of passes minted in this round
        mapping(address => bool) minters;   // Mapping of addresses authorized to mint for this round
    }

    /// @notice Mapping of round ID to RevenueRound struct
    mapping(uint256 => Round) public rounds;

    /// @notice Total number of rounds created
    uint256 public roundCount;

    /* ----------------------- Constructor ------------------------ */

    /// @notice Initializes the contract with uri
    /// @param _uri The base URI for pass NFTs
    constructor(string memory _uri) ERC1155(_uri) {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(Constants.OPERATOR_ROLE, msg.sender);
    }

    /* ----------------------- Admin functions ------------------------ */

    /// @notice Create a new round
    function createRound() external onlyRole(Constants.OPERATOR_ROLE) {
        roundCount++;
        Round storage newRound = rounds[roundCount];
        newRound.creator = msg.sender;

        emit RoundCreated(roundCount, msg.sender);
    }

    /// @notice Set the whitelist for a specific round
    /// @param _roundId The ID of the round
    /// @param _addresses Array of addresses to be whitelisted
    function setMinters(uint256 _roundId, address[] calldata _addresses, bool status) external onlyRole(Constants.OPERATOR_ROLE) {
        Round storage round = rounds[_roundId];
        for (uint256 i = 0; i < _addresses.length; i++) {
            round.minters[_addresses[i]] = status;
        }

        emit MintersUpdated(_roundId, _addresses, status);
    }

    /// @notice Mint mining-pass for a specific round
    /// @param _roundId The ID of the round
    /// @param _quantity The number of pass to mint
    function mint(uint256 _roundId, address _to, uint256 _quantity) external nonReentrant {
        Round storage round = rounds[_roundId];

        if (_to == address(0)) revert Errors.InvalidAddress();
        if (!round.minters[msg.sender]) revert Errors.NotAuthorized();

        _mint(_to, _roundId, _quantity, "");
        round.mintedCount += _quantity;

        emit PassMinted(_roundId, _to, _quantity);
    }

    /* ----------------------- View functions ------------------------ */

    /// @notice Get token URI of mining-pass
    /// @param _tokenId The pass NFT token id
    /// @return The token URI
    function uri(uint256 _tokenId) public view virtual override returns (string memory) {
        return string(abi.encodePacked(super.uri(_tokenId), _tokenId.toString()));
    }

    /// @notice Check if an address is minter for a specific round
    /// @param _roundId The ID of the round
    /// @param _address The address to check
    /// @return bool True if the address is minter, false otherwise
    function isMinter(uint256 _roundId, address _address) public view returns (bool) {
        return rounds[_roundId].minters[_address];
    }

    function supportsInterface(bytes4 interfaceId) public view override(ERC1155, AccessControl) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}
