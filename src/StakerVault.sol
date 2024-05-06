// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {ERC4626} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract StakerVault is ERC4626 {
    constructor(address asset, string memory name, string memory symbol) ERC4626(IERC20(asset)) ERC20(name, symbol){

    }
}
