// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console2} from "forge-std/Script.sol";
import "../src/StakerVault.sol";
import {MachinePassManager} from "../src/markets/MachinePassManager.sol";
import {FaucetToken} from "../src/FaucetToken.sol";
import {MiningLotteryFactory} from "../src/MiningLotteryFactory.sol";

contract MiningLotteryFactoryScript is Script {
    address tUSDT = 0x78137Bb8588D1a8942E73C62881482b1dc650F40;
    address collector = 0xBfE5E7792A91d6f91626d0F08c8052702c9b9c51;

    function setUp() public {}

    function run() public {
        vm.startBroadcast();

//        FaucetToken tUSDT = new FaucetToken("tUSDT", "tUSDT");
        MiningLotteryFactory msf = new MiningLotteryFactory(tUSDT, collector);
        msf.createRound(1000, 10 ether, 1722584384, 1722584384 + 3 * 24 * 3600, 1722584384 + 1 * 24 * 3600, 30);

        vm.stopBroadcast();
    }
}
