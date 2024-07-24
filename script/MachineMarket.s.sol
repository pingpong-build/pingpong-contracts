// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console2} from "forge-std/Script.sol";
import "../src/StakerVault.sol";
import {MachinePassManager} from "../src/markets/MachinePassManager.sol";
import {FaucetToken} from "../src/FaucetToken.sol";
import {MachineMarket} from "../src/markets/MachineMarket.sol";
import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract MachineMarketScript is Script {
    address marketAddress = 0x3255aca301b6c4D808103aB5ad243BeBDF1f419e;
    address passAddress = 0x286A76B5127e526E0683aB1a94B9cfF0AB7cbE1c;
    address owner = 0xBfE5E7792A91d6f91626d0F08c8052702c9b9c51;
    address tUSDT = 0x78137Bb8588D1a8942E73C62881482b1dc650F40;

    function run() public {
        vm.startBroadcast();

        MachineMarket mm = new MachineMarket();
        mm.setPassManagerAddress(1, passAddress);

        vm.stopBroadcast();
    }

    function prepare() public {
        vm.startBroadcast();
        MachineMarket mm = MachineMarket(marketAddress);
//        mm.grantRole(mm.MACHINE_PROVER_ROLE(), 0xBfE5E7792A91d6f91626d0F08c8052702c9b9c51);

//        console2.log(FaucetToken(tUSDT).symbol());
//        FaucetToken(tUSDT).mint(owner, 100 ether);

//        FaucetToken(tUSDT).approve(passAddress, 100000000 ether);
//        MachinePassManager mpm = MachinePassManager(passAddress);
//        uint256 tokenId = mpm.mint(owner, 1, tUSDT);
//        console2.log(tokenId);

        mm.setPassManagerAddress(1, passAddress);

        mm.listMachine("11111111", 1, 0xBfE5E7792A91d6f91626d0F08c8052702c9b9c51);
        ERC721(passAddress).approve(marketAddress, 0);
        mm.borrowMachine(0xBfE5E7792A91d6f91626d0F08c8052702c9b9c51, "11111111", 0);
        vm.stopBroadcast();
    }
}
