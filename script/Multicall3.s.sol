// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.12;

import {Script, console2} from "forge-std/Script.sol";
import {Multicall3} from "../src/Multicall3.sol";

contract Multicall3Script is Script {
    function setUp() public {}

    function run() public {
        vm.startBroadcast();
        new Multicall3();
        vm.stopBroadcast();
    }
}
