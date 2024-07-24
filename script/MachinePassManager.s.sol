// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console2} from "forge-std/Script.sol";
import "../src/StakerVault.sol";
import {MachinePassManager} from "../src/markets/MachinePassManager.sol";
import {FaucetToken} from "../src/FaucetToken.sol";

contract MachinePassManagerScript is Script {
    address tUSDT = 0x78137Bb8588D1a8942E73C62881482b1dc650F40;

    function setUp() public {}

    function run() public {
        vm.startBroadcast();

//        FaucetToken tUSDT = new FaucetToken("tUSDT", "tUSDT");
        MachinePassManager mpm = new MachinePassManager("PP Machine Pass", "PPMP");

        mpm.setType(1, 30 * 24 * 3600, address(tUSDT), 10 ether);

        vm.stopBroadcast();
    }
}
