// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

contract Bridger is AccessControl {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    error WrongBridgeAmount();

    error InsufficientBalance();

    error InvalidAddress();

    event Bridged(address token, address from, address to, uint256 amount);

    function bridge(address token, address to, uint256 amount) public {
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
}
