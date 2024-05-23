// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console2} from "forge-std/Script.sol";
import {MockToken} from "../src/MockToken.sol";
import {MultiMint} from "../src/MultiMint.sol";

contract MockTokenScript is Script {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    function setUp() public {}

    function run() public {
        vm.startBroadcast();
//        MockToken m1 = new MockToken("Mock GRT Token", "GRT", 0xcE150D52d01B7cB0b0E1b37A52BCb2227f8E2D35);
//        MockToken m2 = new MockToken("Mock LPT Token", "LPT", 0xcE150D52d01B7cB0b0E1b37A52BCb2227f8E2D35);
//        address[] memory tokens = new address[](2);
//        tokens[0] = address(m1);
//        tokens[1] = address(m2);
//        MultiMint mm = new MultiMint(0xcE150D52d01B7cB0b0E1b37A52BCb2227f8E2D35, tokens);
//        m1.grantRole(MINTER_ROLE, address(mm));
//        m2.grantRole(MINTER_ROLE, address(mm));

        MockToken t0 = new MockToken("Mapped GRT Token", "GRT", 0xcE150D52d01B7cB0b0E1b37A52BCb2227f8E2D35);
        MockToken t1 =  new MockToken("Mapped LPT Token", "LPT", 0xcE150D52d01B7cB0b0E1b37A52BCb2227f8E2D35);
        t0.grantRole(MINTER_ROLE, 0x54Bb58C72b1174287423719725b2180B2Cd96402);
        t1.grantRole(MINTER_ROLE, 0xbad40f35ceb6Dc57Ad82E2B781c5AE85b0Fc6209);
        vm.stopBroadcast();
    }
}
