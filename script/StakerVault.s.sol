// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console2} from "forge-std/Script.sol";
import "../src/StakerVault.sol";

contract StakerVaultScript is Script {
    function setUp() public {}

    function run() public {
        vm.startBroadcast();
        new StakerVault(0xcE150D52d01B7cB0b0E1b37A52BCb2227f8E2D35, "pGRT", "pGRT");
        vm.stopBroadcast();
    }
}
