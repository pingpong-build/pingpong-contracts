// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console2} from "forge-std/Script.sol";
import "../src/StakerVault.sol";

contract StakerVaultScript is Script {
    function setUp() public {}

    function run() public {
        vm.startBroadcast();
        new StakerVault(0x07511e0c7Ea791c396cc30Dbc2542FAF5D406294, "ppGRT", "ppGRT");
        vm.stopBroadcast();
    }
}
