// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console2} from "forge-std/Script.sol";
import "../src/StakerVault.sol";

contract StakerVaultScript is Script {
    function setUp() public {}

    function run() public {
        vm.startBroadcast();
        new StakerVault(0xb17bE239cf3C15b33CB865D4AcE5e28aa883440B, "ppGRT", "ppGRT");
        new StakerVault(0x0d763880cc7E54749E4FE3065DB53DA839a8eF6b, "ppLPT", "ppLPT");
        vm.stopBroadcast();
    }
}
