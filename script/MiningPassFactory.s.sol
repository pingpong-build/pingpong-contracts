// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console2} from "forge-std/Script.sol";
import "../src/StakerVault.sol";
import {MachinePassManager} from "../src/markets/MachinePassManager.sol";
import {FaucetToken} from "../src/FaucetToken.sol";
import {MiningPassFactory} from "../src/MiningPassFactory.sol";

contract MiningPassFactoryScript is Script {
    address tUSDT = 0x78137Bb8588D1a8942E73C62881482b1dc650F40;
    address collector = 0xBfE5E7792A91d6f91626d0F08c8052702c9b9c51;
    address mpfAddress = 0xC11705DfC88141B01d79187d0C01CcF1c182Ddc5;

    function setUp() public {}

    function run() public {
        vm.startBroadcast();

//        FaucetToken tUSDT = new FaucetToken("tUSDT", "tUSDT");
        MiningPassFactory mpf = new MiningPassFactory(tUSDT, collector, "");
        mpf.createRound(0, 1000, 10 ether, 1724048635, 1724048635 + 7 * 24 * 3600, 1724048635 + 0 * 24 * 3600, 30);

        vm.stopBroadcast();
    }

    function mint() public {
        vm.startBroadcast();

        MiningPassFactory mpf = MiningPassFactory(mpfAddress);
        FaucetToken token = FaucetToken(tUSDT);
        token.approve(address(mpf), 1000 ether);
        mpf.mint(1, 1);

        vm.stopBroadcast();
    }

    function grant() public {
        vm.startBroadcast();

        MiningPassFactory mpf = MiningPassFactory(mpfAddress);
        mpf.grantRole(mpf.OPERATOR_ROLE(), 0x0513b9F7F42666622672d6a52c1E62A76ccC7AB0);

        vm.stopBroadcast();
    }

    function print() public view {
        MiningPassFactory mpf = MiningPassFactory(mpfAddress);
        console2.log(mpf.uri(1));
    }
}
