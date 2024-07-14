// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

interface IMachinePassManager {
    function getPassDuration(uint256 tokenId) external returns (uint256);
}
