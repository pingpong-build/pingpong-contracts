// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console2} from "forge-std/Script.sol";
import {ForwardContractManager} from "../src/forward/ForwardContractManager.sol";
import {MerchantController} from "../src/forward/MerchantController.sol";

contract MerchantControllerScript is Script {
    address controller = 0x1B86125FE74EAE3e950E50EfFe70a35eAFF82277;
    function setUp() public {}

    function run() public {
        vm.startBroadcast();
        new MerchantController();
        vm.stopBroadcast();
    }

    function set() public {
        vm.startBroadcast();
        MerchantController(controller);
        vm.stopBroadcast();
    }
}
