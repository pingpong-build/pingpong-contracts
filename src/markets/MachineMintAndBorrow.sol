// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IMachinePassManager} from "./interfaces/IMachinePassManager.sol";
import {IMachineMarket} from "./interfaces/IMachineMarket.sol";

contract MachineMintAndBorrow {
    IMachineMarket public market;

    constructor(address _market) {
        market = IMachineMarket(_market);
    }

    /**
     * @notice Allows users to mint a pass NFT and borrow a machine in one transaction.
     * @param to The address that will receive the machine.
     * @param machineId The id of the machine being borrowed.
     * @param typeId The type id of the pass NFT to mint.
     * @param paymentToken The address of the payment token.
     */
    function mintAndBorrow( address to, string memory machineId, uint256 typeId, address paymentToken) public {
        uint256 machineType = market.getMachineType(machineId);

        address passManagerAddress = market.passManagerAddresses(machineType);

        uint256 price = IMachinePassManager(passManagerAddress).getPassPrice(typeId, paymentToken);

        IERC20(paymentToken).transferFrom(msg.sender, address(this), price);

        // Mint NFT
        uint256 tokenId = IMachinePassManager(passManagerAddress).mint(msg.sender, typeId, paymentToken);

        // Borrow the machine
        market.borrowMachine(to, machineId, tokenId);
    }
}
