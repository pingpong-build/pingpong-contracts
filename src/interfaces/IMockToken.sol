// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

interface IMockToken {
    function mint(address to, uint256 amount) external;
    function mintWithId(address to, uint256 amount, string memory id) external;
}
