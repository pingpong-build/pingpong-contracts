// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {IERC721} from "../../lib/forge-std/src/interfaces/IERC721.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "./IMachineTickets.sol";

contract MachineMarket is AccessControl {
    IERC721 public machineTickets;
    uint256 public price;
    address public prover;

    struct Machine {
        uint256 machineType;
        uint256 borrowedAt;
        uint256 duration;
    }

    // machine type(1, 2, 3) => tickets nft address
    mapping(uint256 => address) public ticketsAddresses;

    mapping(string => Machine) public machines;

    /**
     * @dev Thrown when transfer failed
     */
    error TransferFailed();

    /**
     * @dev Thrown when transfer failed
     */
    error InvalidTicketOwner(address ticketsAddress);

    /**
     * @dev Thrown when transfer failed
     */
    error InvalidMachineType();

    /**
     * @dev Thrown when transfer failed
     */
    error InvalidMachineId();

    /**
     * @dev Thrown when transfer failed
     */
    error RepeatedMachineBorrowing();

    /**
     * @dev Thrown when transfer failed
     */
    error RepeatedMachineLending();

    /**
     * @dev Thrown when the signer is not prover address
     */
    error InvalidSignature();

    event MachineLent(string machineId, uint256 machineType);

    event MachineBorrowed(address who, string machineId, uint256 tokenId);

    constructor(address _prover) {
        prover = _prover;
    }

    function setProver(address _prover) public onlyRole(DEFAULT_ADMIN_ROLE) {
        prover = _prover;
    }

    function setTicketsAddresses(uint256 machineType, address ticketsAddress) external onlyRole(DEFAULT_ADMIN_ROLE) {
        ticketsAddresses[machineType] = ticketsAddress;
    }

    function lendMachine(string memory machineId, uint256 machineType, bytes memory signature) public {
        if (machines[machineId].machineType != 0) {
            revert RepeatedMachineLending();
        }

        if (ticketsAddresses[machineType] == address(0)) {
            revert InvalidMachineType();
        }

        bytes32 signedHash = keccak256(abi.encodePacked(machineId, machineType));

        address signer = ECDSA.recover(signedHash, signature);
        if (signer != prover) {
            revert InvalidSignature();
        }

        machines[machineId] = Machine(machineType, 0, 0);

        emit MachineLent(machineId, machineType);
    }

    function borrowMachine(string memory machineId, uint256 tokenId) public {
        Machine storage machine = machines[machineId];
        if (machine.machineType == 0) {
            revert InvalidMachineId();
        }

        if (machine.borrowedAt + machine.duration > block.timestamp) {
            revert RepeatedMachineBorrowing();
        }

        address ticketsAddress = ticketsAddresses[machine.machineType];

        if (IERC721(ticketsAddress).ownerOf(tokenId) != msg.sender) {
            revert InvalidTicketOwner(ticketsAddress);
        }

        IERC721(ticketsAddress).transferFrom(msg.sender, address(this), tokenId);

        uint256 duration = IMachineTickets(ticketsAddress).getTicketDuration(tokenId);

        machines[machineId] = Machine(machine.machineType, block.timestamp, duration);

        emit MachineBorrowed(msg.sender, machineId, tokenId);
    }
}
