// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console2} from "forge-std/Script.sol";
import "../src/mint/MiningClaimToken.sol";
import {Constants} from "../src/libraries/Constants.sol";

contract MiningClaimTokenScript is Script {
    function setUp() public {}

    address aiozAddr = 0x599f144c0Ccd941b040398Db679f7a83d2db631a;

    function deploy() public {
        vm.startBroadcast();
        new MiningClaimToken(
            "PING PONG AIOZ",
            "ppAIOZ",
            0x651d62Df78b36DadBb7Cb3FdB797EF9ecE96F769
        );
        vm.stopBroadcast();
    }

    function grantRole() public {
        vm.startBroadcast();
        MiningClaimToken aioz = MiningClaimToken(aiozAddr);
        aioz.grantRole(Constants.OPERATOR_ROLE, 0x600ea447DA94D0a814a8B7bA254aE3D4D31B442C);
    }

    function mint() public {
        vm.startBroadcast();
        MiningClaimToken aioz = MiningClaimToken(aiozAddr);
        aioz.mint(0x600ea447DA94D0a814a8B7bA254aE3D4D31B442C, 1e18);
        vm.stopBroadcast();
    }

    function bridge() public {
        vm.startBroadcast();
        MiningClaimToken aioz = MiningClaimToken(aiozAddr);
        aioz.bridge("0x600ea447DA94D0a814a8B7bA254aE3D4D31B442C", 1e17);
        vm.stopBroadcast();
    }
}
