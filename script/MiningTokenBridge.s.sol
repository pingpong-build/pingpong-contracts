// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Script, console2} from "forge-std/Script.sol";
import {MiningToken} from "../src/mint/MiningToken.sol";
import {MiningTokenBridge} from "../src/mint/MiningTokenBridge.sol";

contract MiningTokenBridgeScript is Script {
    function setUp() public {}

    address aiozBridgeAddr = 0xd010D38215aEd887E92D316FCa863411959D82fe;

    address arbBridgeAddr = 0xEb663188dEAF794494d2c2e4778a2BAe85Ae02EE;
    address arbPPAiozAddr = 0xA93E7Bb0Ea93d18b90ac0ed108D6c4e3CA555c33;

    function deployArb() public {
        vm.startBroadcast();
        MiningTokenBridge arbBridge = new MiningTokenBridge("42161", 0x2728F6d8C4cB67a3395c4F0Eea93Cbd033DaCC3A, msg.sender, 1e5);
        new MiningToken("PING PONG AIOZ", "ppAIOZ", address(arbBridge));
        vm.stopBroadcast();
    }

    function deployAioz() public {
        vm.startBroadcast();
        new MiningTokenBridge("168", 0x2728F6d8C4cB67a3395c4F0Eea93Cbd033DaCC3A, msg.sender, 1e5);
        vm.stopBroadcast();
    }

    function bridgeToArb() public {
        vm.startBroadcast();
        MiningTokenBridge arbBridge = MiningTokenBridge(aiozBridgeAddr);
        string memory target = Strings.toHexString(uint160(0xaaD350C180f20eEAAf90B7aC4A37443f6dB251B6), 20);
        arbBridge.bridge{value: 1e17}("42161", address(0), target, 1e17);
        vm.stopBroadcast();
    }

    function bridgeArbToAioz() public {
        vm.startBroadcast();
        // IERC20 token = IERC20(arbPPAiozAddr);
        // token.approve(arbBridgeAddr, type(uint256).max);
        MiningTokenBridge arbBridge = MiningTokenBridge(arbBridgeAddr);
        string memory sender = Strings.toHexString(uint160(msg.sender), 20);
        // console2.log(msg.sender);
        // console2.log(sender);
        arbBridge.bridge("168", arbPPAiozAddr, sender, 1e10);
        vm.stopBroadcast();
    }
}
