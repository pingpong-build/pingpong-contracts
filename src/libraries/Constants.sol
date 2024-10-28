// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

library Constants {
    /// @notice WAD precision (18 decimals - 1e18)
    uint256 public constant WAD = 1e18;

    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");

    bytes32 public constant PYTH_ATH_PRICE_FEED_ID = 0xf6b551a947e7990089e2d5149b1e44b369fcc6ad3627cb822362a2b19d24ad4a; // ATH/USD
}
