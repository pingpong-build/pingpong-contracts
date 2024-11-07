// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console2} from "forge-std/Script.sol";
import {ForwardContractManager} from "../src/forward/ForwardContractManager.sol";
import {MerchantController} from "../src/forward/MerchantController.sol";

contract MerchantControllerScript is Script {
    function setUp() public {}

    function run() public {
        vm.startBroadcast();
        new MerchantController();
        vm.stopBroadcast();
    }
}
