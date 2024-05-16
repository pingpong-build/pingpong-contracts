// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "./interfaces/IMockToken.sol";

contract MultiMint is AccessControl {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    address[] public tokens;

    constructor(address minter, address[] memory _tokens) {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, minter);
        _grantRole(MINTER_ROLE, msg.sender);

        tokens = _tokens;
    }

    function setTokens(address[] memory _tokens) public onlyRole(MINTER_ROLE) {
        tokens = _tokens;
    }

    function mint(address to, uint256 amount) public onlyRole(MINTER_ROLE) {
        for (uint i = 0; i < tokens.length; i++) {
            IMockToken(tokens[i]).mint(to, amount);
        }
    }

    function mintWithId(address to, uint256 amount, string memory id) public onlyRole(MINTER_ROLE) {
        for (uint i = 0; i < tokens.length; i++) {
            IMockToken(tokens[i]).mintWithId(to, amount, id);
        }
    }
}
