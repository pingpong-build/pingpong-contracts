// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console2} from "forge-std/Script.sol";
import {MappedToken} from "../src/MappedToken.sol";

contract MappedTokenScript is Script {
    function setUp() public {}

    function run() public {
        vm.startBroadcast();
        MappedToken m = new MappedToken("Mapped AKT Token", "AKT", 0xcE150D52d01B7cB0b0E1b37A52BCb2227f8E2D35);
        console2.log(address(m));
        vm.stopBroadcast();
    }
}
