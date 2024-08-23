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
    address msf = 0xC11705DfC88141B01d79187d0C01CcF1c182Ddc5;

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

        MiningShareFactory msf = MiningShareFactory(msf);
        FaucetToken tUSDT = FaucetToken(tUSDT);
        tUSDT.approve(address(msf), 1000 ether);
        msf.mint(1);

        vm.stopBroadcast();
    }

    function grant() public {
        vm.startBroadcast();

        MiningShareFactory msf = MiningShareFactory(msf);
        msf.grantRole(msf.OPERATOR_ROLE(), 0x0513b9F7F42666622672d6a52c1E62A76ccC7AB0);

        vm.stopBroadcast();
    }

    function setBaseURI() public {
        vm.startBroadcast();

        MiningShareFactory msf = MiningShareFactory(msf);
        msf.setBaseURI("https://resource.pingpong.build/static/future/");

        vm.stopBroadcast();
    }

    function print() public view {
        MiningShareFactory msf = MiningShareFactory(0xC11705DfC88141B01d79187d0C01CcF1c182Ddc5);
        console2.log(msf.baseURI());
        console2.log(msf.tokenURI(1 << 128 | 0));
    }
}
