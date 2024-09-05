// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console2} from "forge-std/Script.sol";
import "../src/StakerVault.sol";
import {MachinePassManager} from "../src/markets/MachinePassManager.sol";
import {FaucetToken} from "../src/FaucetToken.sol";
import {MiningPassFactory} from "../src/MiningPassFactory.sol";
import {Constants} from "./constants.sol";

contract MiningPassFactoryScript is Script, Constants {
    uint256 chainId = uint256(vm.envUint("CHAIN_ID"));
    address usdt;
    address collector;
    address mpfAddress = 0xC3f1823dC102d95E063e8d226331356086945236;

    function setUp() public {
        console2.log("CHAIN_ID: ", chainId);
        if (chainId == 137) {
            usdt = Constants.polygonUsdt;
            collector = Constants.polygonCollector;
        } else {
            usdt = Constants.amoyUsdt;
            collector = Constants.amoyCollector;
        }
    }

    function run() public {
        vm.startBroadcast();

        MiningPassFactory mpf = new MiningPassFactory(usdt, collector, "https://resource.pingpong.build/static/future/");
        mpf.createRound(0, 1000, 0.0001 * 1000_000, block.timestamp, block.timestamp + 7 * 24 * 3600, block.timestamp + 0 * 24 * 3600, 30);

        vm.stopBroadcast();
    }

    function mint() public {
        vm.startBroadcast();

        MiningPassFactory mpf = MiningPassFactory(mpfAddress);
        FaucetToken token = FaucetToken(usdt);
        token.approve(mpfAddress, 10 * 1000_000);
        mpf.mint(1, 1);
        mpf.mint(1, 2);

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
