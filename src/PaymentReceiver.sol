// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// @title PaymentReceiver
/// @notice This contract manages the receiving of payments in native tokens and ERC20 tokens
/// @dev Inherits from Ownable and ReentrancyGuard
contract PaymentReceiver is Ownable, ReentrancyGuard {

    /* ----------------------- Constants ------------------------ */

    /// @notice Address to receive the payments
    address public receiver;

    /* ----------------------- Events ------------------------ */

    /// @notice Emitted when a payment is received
    event PaymentReceived(address indexed payer, address tokenAddress, uint256 amount);

    /// @notice Emitted when the payment receiver is updated
    event ReceiverUpdated(address indexed oldReceiver, address indexed newReceiver);

    /// @notice Emitted when ERC20 tokens are rescued by the admin
    event ERC20Rescued(address indexed tokenAddress, address indexed to, uint256 amount);

    /* ----------------------- Errors ------------------------ */

    /// @notice Error thrown when an invalid address is provided
    error InvalidAddress();

    /// @notice Error thrown when the transfer of tokens fails
    error TransferFailed();

    /* ----------------------- Constructor ------------------------ */

    /// @notice Initializes the contract with the payment receiver address
    /// @param _receiver Address to receive the payments
    constructor(address _receiver) {
        if (_receiver == address(0)) {
            revert InvalidAddress();
        }
        receiver = _receiver;
    }

    /* ----------------------- Admin functions ------------------------ */

    /// @notice Update the payment receiver address
    /// @param newReceiver The new address to receive payments
    function updateReceiver(address newReceiver) external onlyOwner {
        if (newReceiver == address(0)) {
            revert InvalidAddress();
        }
        address oldReceiver = receiver;
        receiver = newReceiver;
        emit ReceiverUpdated(oldReceiver, newReceiver);
    }

    /// @notice Rescue ERC20 tokens that were accidentally sent to this contract
    /// @param tokenAddress The address of the ERC20 token to rescue
    /// @param to The address to send the rescued tokens to
    /// @param amount The amount of tokens to rescue
    function rescueERC20(address tokenAddress, address to, uint256 amount) external onlyOwner {
        if (tokenAddress == address(0) || to == address(0)) {
            revert InvalidAddress();
        }

        bool success = IERC20(tokenAddress).transfer(to, amount);
        if (!success) {
            revert TransferFailed();
        }

        emit ERC20Rescued(tokenAddress, to, amount);
    }

    /* ----------------------- External functions ------------------------ */

    /// @notice Receive native tokens
    receive() external payable {
        (bool sent, ) = receiver.call{value: msg.value}("");
        if (!sent) {
            revert TransferFailed();
        }

        emit PaymentReceived(msg.sender, address(0), msg.value);
    }

    /// @notice Make a payment with ERC20 tokens
    /// @param tokenAddress The address of the ERC20 token
    /// @param amount The amount of tokens to transfer
    function pay(address tokenAddress, uint256 amount) external nonReentrant {
        if (tokenAddress == address(0)) {
            revert InvalidAddress();
        }

        bool success = IERC20(tokenAddress).transferFrom(msg.sender, receiver, amount);
        if (!success) {
            revert TransferFailed();
        }

        emit PaymentReceived(msg.sender, tokenAddress, amount);
    }
}
