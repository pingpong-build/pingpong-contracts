// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console2} from "forge-std/Script.sol";
import {Bridger} from "../src/Bridger.sol";
import {BridgerV2} from "../src/BridgerV2.sol";

contract BridgerScript is Script {
    function setUp() public {}

    function run() public {
        vm.startBroadcast();
        new BridgerV2();
        vm.stopBroadcast();
    }
}
