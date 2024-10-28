// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

library Errors {
    /// @notice Error when an invalid address is provided
    error InvalidAddress();

    /// @notice Error when an invalid amount is provided
    error InvalidAmount();

    /// @notice Error when caller is not authorized to action
    error NotAuthorized();

    /// @notice Error when array length is invalid
    error InvalidArrayLength();

    /// @notice Error when transfer fails
    error TransferFailed();

    /// @notice Error when insufficient balance
    error InsufficientBalance();

    /// @notice Error when token is not supported
    error TokenNotSupported();
}
