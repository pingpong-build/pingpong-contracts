// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console2} from "forge-std/Script.sol";
import {MockToken} from "../src/MockToken.sol";

contract MockTokenScript is Script {
    function setUp() public {}

    function run() public {
        vm.startBroadcast();
        new MockToken("Mock GRT Token", "GRT", 0xcE150D52d01B7cB0b0E1b37A52BCb2227f8E2D35);
        new MockToken("Mock LPT Token", "LPT", 0xcE150D52d01B7cB0b0E1b37A52BCb2227f8E2D35);
//        new MockToken("Mapped GRT Token", "GRT", 0xcE150D52d01B7cB0b0E1b37A52BCb2227f8E2D35);
//        new MockToken("Mapped LPT Token", "LPT", 0xcE150D52d01B7cB0b0E1b37A52BCb2227f8E2D35);
        vm.stopBroadcast();
    }
}
