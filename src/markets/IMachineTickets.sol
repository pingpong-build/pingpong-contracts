// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

interface IMachineTickets {
    function getTicketDuration(uint256 tokenId) external returns (uint256);
}
