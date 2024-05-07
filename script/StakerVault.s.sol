// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console2} from "forge-std/Script.sol";
import "../src/StakerVault.sol";

contract StakerVaultScript is Script {
    function setUp() public {}

    function run() public {
        vm.startBroadcast();
        new StakerVault(0x67F89748Da3349e394A0474A2EF0BC380aE21f4b, "ppGRT", "ppGRT");
        new StakerVault(0x83576E2B35F858aB47E32A2e9B9Af6ea68BaD839, "ppLPT", "ppLPT");
        vm.stopBroadcast();
    }
}
