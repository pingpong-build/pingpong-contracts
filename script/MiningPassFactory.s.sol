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
        mpf.createRound(1, 2500, 40 * 1000_000, block.timestamp, block.timestamp + 30 * 24 * 3600, block.timestamp, 30);

        vm.stopBroadcast();
    }

    function mint() public {
        vm.startBroadcast();

        MiningPassFactory mpf = MiningPassFactory(mpfAddress);
        FaucetToken token = FaucetToken(usdt);
//        token.approve(mpfAddress, 10 * 1000_000);
        mpf.mint(1, 10);

        vm.stopBroadcast();
    }

    function grant() public {
        vm.startBroadcast();

        MiningPassFactory mpf = MiningPassFactory(mpfAddress);
        mpf.grantRole(mpf.DEFAULT_ADMIN_ROLE(), 0xB90C7395D52e8af26773EB89250DbEaAAc107c01);
//        mpf.grantRole(mpf.OPERATOR_ROLE(), 0xB90C7395D52e8af26773EB89250DbEaAAc107c01);

        vm.stopBroadcast();
    }

    function revoke() public {
        vm.startBroadcast();

        MiningPassFactory mpf = MiningPassFactory(mpfAddress);
        mpf.revokeRole(mpf.OPERATOR_ROLE(), 0x3212dBfCA59b74F5eD208b64f171a0C8BcF2e8C0);
        mpf.revokeRole(mpf.DEFAULT_ADMIN_ROLE(), 0x3212dBfCA59b74F5eD208b64f171a0C8BcF2e8C0);

        vm.stopBroadcast();
    }

    function print() public view {
        MiningPassFactory mpf = MiningPassFactory(mpfAddress);
        console2.log(mpf.uri(1));
    }
}
