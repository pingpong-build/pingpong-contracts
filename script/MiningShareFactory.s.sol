// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console2} from "forge-std/Script.sol";
import "../src/StakerVault.sol";
import {MachinePassManager} from "../src/markets/MachinePassManager.sol";
import {FaucetToken} from "../src/FaucetToken.sol";
import {MiningShareFactory} from "../src/MiningShareFactory.sol";

contract MiningShareFactoryScript is Script {
    address tUSDT = 0x78137Bb8588D1a8942E73C62881482b1dc650F40;
    address collector = 0xBfE5E7792A91d6f91626d0F08c8052702c9b9c51;

    function setUp() public {}

    function run() public {
        vm.startBroadcast();

//        FaucetToken tUSDT = new FaucetToken("tUSDT", "tUSDT");
        MiningShareFactory msf = new MiningShareFactory(tUSDT, collector);
        msf.createRound(0, 1000, 10 ether, 1724048635, 1724048635 + 7 * 24 * 3600, 1724048635 + 0 * 24 * 3600, 30);

        vm.stopBroadcast();
    }

    function mint() public {
        vm.startBroadcast();

        MiningShareFactory msf = MiningShareFactory(0xC11705DfC88141B01d79187d0C01CcF1c182Ddc5);
        FaucetToken tUSDT = FaucetToken(tUSDT);
        tUSDT.approve(address(msf), 1000 ether);
        msf.mint(1);

        vm.stopBroadcast();
    }
}
