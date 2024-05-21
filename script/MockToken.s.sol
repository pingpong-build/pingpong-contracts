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
        MockToken m1 = new MockToken("Mock GRT Token", "GRT", 0xcE150D52d01B7cB0b0E1b37A52BCb2227f8E2D35);
        MockToken m2 = new MockToken("Mock LPT Token", "LPT", 0xcE150D52d01B7cB0b0E1b37A52BCb2227f8E2D35);
        address[] memory tokens = new address[](2);
        tokens[0] = address(m1);
        tokens[1] = address(m2);
        MultiMint mm = new MultiMint(0xcE150D52d01B7cB0b0E1b37A52BCb2227f8E2D35, tokens);

//        mm.grantRole(MINTER_ROLE, 0x4a6A31787fcef281c426529061eD13aFFCD28724);
//        mm.grantRole(MINTER_ROLE, 0xcE150D52d01B7cB0b0E1b37A52BCb2227f8E2D35);
        m1.grantRole(MINTER_ROLE, address(mm));
        m2.grantRole(MINTER_ROLE, address(mm));
//        MockToken t0 = new MockToken("Mapped GRT Token", "GRT", 0xcE150D52d01B7cB0b0E1b37A52BCb2227f8E2D35);
//        MockToken t1 =  new MockToken("Mapped LPT Token", "LPT", 0xcE150D52d01B7cB0b0E1b37A52BCb2227f8E2D35);
//        t0.grantRole(keccak256("MINTER_ROLE"), 0xCA5BDEf33c17c7633E84D94ED6EEF9f1A0aBE71d);
//        t1.grantRole(keccak256("MINTER_ROLE"), 0x03CE37d18Cb4A7c26Bec5a860c564C0E8d4811B3);
        vm.stopBroadcast();
    }
}
