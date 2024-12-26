// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import {Constants} from "../libraries/Constants.sol";
import {Errors} from "../libraries/Errors.sol";

/// @title MiningClaimToken
/// @notice ERC20 token representing mining claims
/// @dev Implements ERC20 for token management, AccessControl for permissions
contract MiningToken is ERC20, AccessControl {
    
    /// @notice Event emitted when tokens are minted
    /// @param to Address of the recipient
    /// @param amount Amount of tokens minted
    event Minted(address indexed to, uint256 amount);

    /// @notice Initialize the contract
    /// @param name Name of the token
    /// @param symbol Symbol of the token
    /// @param operator Address of the operator
    constructor(string memory name, string memory symbol, address operator) ERC20(name, symbol) {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(Constants.OPERATOR_ROLE, operator);
    }
    
    /// @notice Mint tokens
    /// @param to Address to mint tokens to
    /// @param amount Amount of tokens to mint
    function mint(address to, uint256 amount) public onlyRole(Constants.OPERATOR_ROLE) {
        _mint(to, amount);

        emit Minted(to, amount);
    }
}