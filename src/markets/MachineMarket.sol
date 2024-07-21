// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {IERC721} from "../../lib/forge-std/src/interfaces/IERC721.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "./interfaces/IMachinePassManager.sol";
import {IMachineMarket} from "./interfaces/IMachineMarket.sol";

contract MachineMarket is AccessControl, IMachineMarket {

    bytes32 public constant MACHINE_PROVER_ROLE = keccak256("MACHINE_PROVER");

    /* ----------------------- Storage ------------------------ */

    /// @notice Tracks all passManagerAddress, indexed by machine type
    // machine type (1, 2, 3) => passManagerAddress
    mapping(uint256 => address) public passManagerAddresses;

    /// @notice Tracks all machines, indexed by machine id
    // machine id => machine
    mapping(string => Machine) public machines;

    /* --------------------- Constructor ---------------------- */

    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    /* ------------------- Admin functions -------------------- */

    /**
     * @notice Admin can set passManagerAddress
     * @param machineType The machine type
     * @param passManagerAddress The passManagerAddress
     */
    function setPassManagerAddress(uint256 machineType, address passManagerAddress) external onlyRole(DEFAULT_ADMIN_ROLE) {
        passManagerAddresses[machineType] = passManagerAddress;
    }

    /**
     * @notice Machine prover can list machine
     * @param machineId The machine id
     * @param machineType The machine type
     */
    function listMachine(string memory machineId, uint256 machineType) public onlyRole(MACHINE_PROVER_ROLE) {
        if (machines[machineId].machineType != 0) {
            revert RepeatedMachineListing();
        }

        if (passManagerAddresses[machineType] == address(0)) {
            revert InvalidMachineType();
        }

        machines[machineId] = Machine(machineType, 0, 0, address(0), false);

        emit MachineListed(machineId, machineType);
    }

    /* ----------------------- User functions ------------------------ */

    /**
     * @notice Allows users to borrow machine of the specified machineId by paying with the specified pass nft.
     * @param to The address that will receive machine.
     * @param machineId The id of the machine being borrowed.
     * @param tokenId The pass nft tokenId.
     */
    function borrowMachine(address to, string memory machineId, uint256 tokenId, string memory data) public {
        if (to == address(0)) {
            revert InvalidToAddress();
        }

        Machine storage machine = machines[machineId];
        if (machine.machineType == 0) {
            revert InvalidMachineId();
        }

        if (machine.borrower != address(0) && (machine.updated && machine.borrowedAt + machine.duration > block.timestamp)) {
            revert RepeatedMachineBorrowing();
        }

        address passManagerAddress = passManagerAddresses[machine.machineType];

        if (IERC721(passManagerAddress).ownerOf(tokenId) != msg.sender) {
            revert InvalidPassOwner(passManagerAddress);
        }

        IERC721(passManagerAddress).transferFrom(msg.sender, address(this), tokenId);

        uint256 duration = IMachinePassManager(passManagerAddress).getPassDuration(tokenId);

        machine.borrower = to;
        machine.duration = duration;
        machine.updated = false;

        emit MachineBorrowed(to, machineId, tokenId, duration, data);
    }

    /**
     * @notice Allows users to renew machine of the specified machineId by paying with the specified pass nft.
     * @param machineId The id of the machine being borrowed.
     * @param tokenId The pass nft tokenId.
     */
    function renewMachine(string memory machineId, uint256 tokenId) public {
        Machine storage machine = machines[machineId];
        if (machine.machineType == 0) {
            revert InvalidMachineId();
        }

        if (machine.borrower != msg.sender) {
            revert RenewFailed();
        }

        address passManagerAddress = passManagerAddresses[machine.machineType];

        if (IERC721(passManagerAddress).ownerOf(tokenId) != msg.sender) {
            revert InvalidPassOwner(passManagerAddress);
        }

        uint256 additionalDuration = IMachinePassManager(passManagerAddress).getPassDuration(tokenId);

        machine.duration += additionalDuration;

        emit MachineRenewed(msg.sender, machineId, tokenId, additionalDuration);
    }

    function getMachineType(string memory machineId) public view returns (uint256) {
        return machines[machineId].machineType;
    }
}
