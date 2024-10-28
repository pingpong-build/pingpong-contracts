// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Errors} from "../libraries/Errors.sol";

contract ForwardExchanger is ReentrancyGuard {

    /* ----------------------- Storage ------------------------ */

    address public immutable deliveryToken;       // Token to be delivered by shipper
    uint256 public immutable deliveryAmount;      // Amount of tokens to be delivered
    address public immutable paymentToken;        // Token to be paid by consignee (address(0) for ETH)
    uint256 public immutable paymentAmount;       // Amount to be paid
    uint256 public immutable expiredAt;          // Timestamp when the exchange expires
    address public immutable consignee;          // Address of consignee who needs to pay
    address public immutable shipper;            // Address of shipper who needs to deliver

    bool public isPaid;                          // True if consignee has paid
    bool public isDelivered;                     // True if shipper has delivered
    bool public isExchanged;                     // True if exchange is completed and assets are transferred

    /* ----------------------- Events ------------------------ */

    event Paid(address payer, uint256 amount);
    event Delivered(address deliverer, uint256 amount);
    event Exchanged(address consignee, address shipper);
    event Refunded();

    /* ----------------------- Errors ------------------------ */

    error InvalidTime();
    error ExchangeFailed();
    error RefundFailed();
    error AlreadyPaid();
    error AlreadyDelivered();

    /* ----------------------- Constructor ------------------------ */

    /// @notice Constructor to initialize the contract
    constructor(
        address _deliveryToken,
        uint256 _deliveryAmount,
        address _paymentToken,
        uint256 _paymentAmount,
        uint256 _expiredAt,
        address _consignee,
        address _shipper
    ) {
        if (_deliveryToken == address(0) || _consignee == address(0) || _shipper == address(0)) {
            revert Errors.InvalidAddress();
        }

        if (_expiredAt <= block.timestamp) revert InvalidTime();

        deliveryToken = _deliveryToken;
        deliveryAmount = _deliveryAmount;
        paymentToken = _paymentToken;
        paymentAmount = _paymentAmount;
        expiredAt = _expiredAt;
        consignee = _consignee;
        shipper = _shipper;
    }

    /* ----------------------- Public Functions ------------------------ */

    function pay() external payable {
        if (isPaid) revert AlreadyPaid();
        if (expiredAt < block.timestamp) revert InvalidTime();

        if (paymentToken == address(0)) {
            if (msg.value < paymentAmount) {
                revert Errors.InsufficientBalance();
            }

            if (msg.value > paymentAmount) {
                (bool refundSuccess,) = msg.sender.call{value: msg.value - paymentAmount}("");
                if (!refundSuccess) revert Errors.TransferFailed();
            }
        } else {
            bool success = IERC20(paymentToken).transferFrom(msg.sender, address(this), paymentAmount);
            if (!success) {
                revert Errors.TransferFailed();
            }
        }

        isPaid = true;

        emit Paid(msg.sender, paymentAmount);
    }

    function deliver() external {
        if (isDelivered) revert AlreadyDelivered();
        if (expiredAt < block.timestamp) revert InvalidTime();

        bool success = IERC20(deliveryToken).transferFrom(msg.sender, address(this), deliveryAmount);
        if (!success) {
            revert Errors.TransferFailed();
        }
        isDelivered = true;

        emit Delivered(msg.sender, deliveryAmount);
    }

    function exchange() external nonReentrant {
        if (!isPaid || !isDelivered) revert ExchangeFailed();
        if (isExchanged) revert ExchangeFailed();

        if (paymentToken == address(0)) {
            (bool success,) = shipper.call{value: paymentAmount}("");
            if (!success) revert Errors.TransferFailed();
        } else {
            bool success = IERC20(paymentToken).transfer(shipper, paymentAmount);
            if (!success) revert Errors.TransferFailed();
        }

        bool deliverySuccess = IERC20(deliveryToken).transfer(consignee, deliveryAmount);
        if (!deliverySuccess) revert Errors.TransferFailed();

        isExchanged = true;

        emit Exchanged(consignee, shipper);
    }

    function refund() external nonReentrant {
        if (expiredAt >= block.timestamp) revert InvalidTime();
        if (isExchanged) revert RefundFailed();

        if (isPaid) {
            if (paymentToken == address(0)) {
                (bool success,) = consignee.call{value: paymentAmount}("");
                if (!success) revert Errors.TransferFailed();
            } else {
                bool success = IERC20(paymentToken).transfer(consignee, paymentAmount);
                if (!success) revert Errors.TransferFailed();
            }

            isPaid = false;
        }

        if (isDelivered) {
            bool deliverySuccess = IERC20(deliveryToken).transfer(shipper, deliveryAmount);
            if (!deliverySuccess) revert Errors.TransferFailed();

            isDelivered = false;
        }

        emit Refunded();
    }

    receive() external payable {}
}
