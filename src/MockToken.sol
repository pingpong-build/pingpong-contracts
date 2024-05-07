// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

contract MockToken is ERC20, AccessControl {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    mapping(string => bool) public ids;

    error RepeatedID(string id);

    constructor(string memory name, string memory symbol, address minter) ERC20(name, symbol) {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, minter);
    }

    function mint(address to, uint256 amount) public onlyRole(MINTER_ROLE) {
        _mint(to, amount);
    }

    function mintWithId(address to, uint256 amount, string memory id) public onlyRole(MINTER_ROLE) {
        if (ids[id]) {
            revert RepeatedID(id);
        }

        ids[id] = true;

        _mint(to, amount);
    }
}
