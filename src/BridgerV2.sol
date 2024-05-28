// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

contract BridgerV2 is AccessControl {
    uint256 public bridgeFee = 0.0015 ether;

    error WrongBridgeAmount();

    error InsufficientBalance();

    error InvalidAddress();

    error WrongBridgeFee(uint256 amount);

    event Bridged(address token, address from, address to, uint256 amount);

    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    function setBridgeFee(uint256 fee) public onlyRole(DEFAULT_ADMIN_ROLE) {
        bridgeFee = fee;
    }

    function bridge(address token, address to, uint256 amount) public payable {
        if (msg.value < bridgeFee) {
            revert WrongBridgeFee(msg.value);
        }

        if (amount <= 0) {
            revert WrongBridgeAmount();
        }

        if (IERC20(token).balanceOf(msg.sender) < amount) {
            revert InsufficientBalance();
        }

        if (to == address(0)) {
            revert InvalidAddress();
        }


        IERC20(token).transferFrom(msg.sender, address(this), amount);

        emit Bridged(token, msg.sender, to, amount);
    }

    // Withdraw bridge fee
    function withdraw() public onlyRole(DEFAULT_ADMIN_ROLE) {
        payable(msg.sender).transfer(address(this).balance);
    }
}
