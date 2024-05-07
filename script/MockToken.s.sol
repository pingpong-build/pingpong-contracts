// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console2} from "forge-std/Script.sol";
import {MockToken} from "../src/MockToken.sol";

contract MockTokenScript is Script {
    function setUp() public {}

    function run() public {
        vm.startBroadcast();
//        new MockToken("Mock GRT Token", "GRT", 0xcE150D52d01B7cB0b0E1b37A52BCb2227f8E2D35);
//        new MockToken("Mock LPT Token", "LPT", 0xcE150D52d01B7cB0b0E1b37A52BCb2227f8E2D35);
        MockToken t0 = new MockToken("Mapped GRT Token", "GRT", 0xcE150D52d01B7cB0b0E1b37A52BCb2227f8E2D35);
        MockToken t1 =  new MockToken("Mapped LPT Token", "LPT", 0xcE150D52d01B7cB0b0E1b37A52BCb2227f8E2D35);
        t0.grantRole(keccak256("MINTER_ROLE"), 0xCA5BDEf33c17c7633E84D94ED6EEF9f1A0aBE71d);
        t1.grantRole(keccak256("MINTER_ROLE"), 0x03CE37d18Cb4A7c26Bec5a860c564C0E8d4811B3);
        vm.stopBroadcast();
    }
}
