// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {IERC721} from "../../lib/forge-std/src/interfaces/IERC721.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "./interfaces/IMachinePassManager.sol";
import {IMachineMarket} from "./interfaces/IMachineMarket.sol";

/// @title MachineMarket
/// @notice This contract manages the listing, borrowing, and updating of machines
/// @dev Implements AccessControl for role-based permissions
contract MachineMarket is AccessControl, IMachineMarket {
    bytes32 public constant MACHINE_PROVER_ROLE = keccak256("MACHINE_PROVER");
    bytes32 public constant MACHINE_MANAGER_ROLE = keccak256("MACHINE_MANAGER");

    /* ----------------------- Storage ------------------------ */

    /// @notice Tracks all passManagerAddress, indexed by machine type
    /// @dev machine type (1, 2, 3) => passManagerAddress
    mapping(uint256 => address) public passManagerAddresses;

    /// @notice Tracks all machines, indexed by machine id
    /// @dev machine id => machine
    mapping(string => Machine) public machines;

    /* --------------------- Constructor ---------------------- */

    /// @notice Sets up the contract and grants the DEFAULT_ADMIN_ROLE to the deployer
    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    /* ------------------- Admin functions -------------------- */

    /// @notice Admin can set passManagerAddress
    /// @param machineType The machine type
    /// @param passManagerAddress The passManagerAddress
    function setPassManagerAddress(uint256 machineType, address passManagerAddress) external onlyRole(DEFAULT_ADMIN_ROLE) {
        passManagerAddresses[machineType] = passManagerAddress;
        emit PassManagerAddressSet(machineType, passManagerAddress);
    }

    /// @notice Machine prover can list machine
    /// @param machineId The machine id
    /// @param machineType The machine type
    function listMachine(string memory machineId, uint256 machineType, address owner) public onlyRole(MACHINE_PROVER_ROLE) {
        if (machines[machineId].machineType != 0) {
            revert RepeatedMachineListing();
        }

        if (passManagerAddresses[machineType] == address(0)) {
            revert InvalidMachineType();
        }

        machines[machineId] = Machine(machineType, owner, 0, 0, address(0), false, true);

        emit MachineListed(machineId, machineType, owner);
    }

    /// @notice Machine prover can delist machine
    /// @param machineId The machine id
    function delistMachine(string memory machineId) public onlyRole(MACHINE_PROVER_ROLE) {
        Machine storage machine = machines[machineId];
        if (machine.machineType == 0) {
            revert InvalidMachineId();
        }

        machine.isAvailable = false;

        emit MachineDelisted(machineId);
    }

    /// @notice Allows machine managers to update the borrowed status of a machine
    /// @param machineId The id of the machine to update
    /// @param borrowedAt The timestamp when the machine was borrowed
    function updateMachine(string memory machineId, uint256 borrowedAt) public onlyRole(MACHINE_MANAGER_ROLE) {
        Machine storage machine = machines[machineId];
        if (machine.machineType == 0) {
            revert InvalidMachineId();
        }

        machine.borrowedAt = borrowedAt;
        machine.updated = true;

        emit MachineUpdated(machineId, borrowedAt);
    }

    /// @notice Allows admin to rescue tokens accidentally sent to this contract
    /// @param to The address to send the rescued tokens to
    /// @param token The IERC20 token to rescue
    function rescueToken(address to, IERC20 token) external onlyRole(DEFAULT_ADMIN_ROLE) {
        uint256 total = token.balanceOf(address(this));
        token.transfer(to, total);
    }

    /* ----------------------- User functions ------------------------ */

    /// @notice Allows users to borrow machine of the specified machineId by paying with the specified pass nft.
    /// @param to The address that will receive machine.
    /// @param machineId The id of the machine being borrowed.
    /// @param tokenId The pass nft tokenId.
    function borrowMachine(address to, string memory machineId, uint256 tokenId) public {
        if (to == address(0)) revert InvalidToAddress();

        Machine storage machine = machines[machineId];
        if (machine.machineType == 0) revert InvalidMachineId();
        if (!machine.isAvailable) revert UnavailableMachine();

        bool isBorrowingAlready = isBorrowing(machine);
        if (isBorrowingAlready && machine.borrower != to) revert RepeatedMachineBorrowing();

        address passManagerAddress = passManagerAddresses[machine.machineType];
        if (IERC721(passManagerAddress).ownerOf(tokenId) != msg.sender) revert InvalidPassOwner(passManagerAddress);

        uint256 duration = IMachinePassManager(passManagerAddress).getPassDuration(tokenId);

        if (isBorrowingAlready && machine.borrower == to) {
            machine.duration += duration;
        } else {
            machine.borrower = to;
            machine.duration = duration;
        }
        machine.updated = false;

        IERC721(passManagerAddress).transferFrom(msg.sender, address(this), tokenId);

        emit MachineBorrowed(to, machineId, tokenId, duration, isBorrowingAlready);
    }

    /* ----------------------- View functions ------------------------ */

    /// @notice Gets the type of a specific machine
    /// @param machineId The id of the machine
    /// @return The type of the machine
    function getMachineType(string memory machineId) public view returns (uint256) {
        return machines[machineId].machineType;
    }

    /// @notice Checks if a machine is currently being borrowed
    /// @param machine The Machine struct to check
    /// @return A boolean indicating if the machine is being borrowed
    function isBorrowing(Machine memory machine) public view returns (bool) {
        return machine.borrower != address(0) && (!machine.updated || machine.borrowedAt + machine.duration > block.timestamp);
    }
}
