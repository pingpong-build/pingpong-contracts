// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {IERC721} from "../../lib/forge-std/src/interfaces/IERC721.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "./IMachinePassManager.sol";

contract MachineMarket is AccessControl {
    IERC721 public machinePassManager;
    uint256 public price;
    address public prover;

    struct Machine {
        uint256 machineType;
        uint256 borrowedAt;
        uint256 duration;
        address borrower;
        bool updated;
    }

    // machine type(1, 2, 3) => passManagerAddress
    mapping(uint256 => address) public passManagerAddresses;

    // machine id => Machine
    mapping(string => Machine) public machines;

    /**
     * @dev Thrown when transfer failed
     */
    error TransferFailed();

    /**
     * @dev Thrown when transfer failed
     */
    error InvalidPassOwner(address passAddress);

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
    error RenewFailed();

    /**
     * @dev Thrown when transfer failed
     */
    error RepeatedMachineLending();

    /**
     * @dev Thrown when the signer is not prover address
     */
    error InvalidSignature();

    /**
     * @dev Thrown when to address is empty
     */
    error InvalidToAddress(address to);

    event MachineLent(string machineId, uint256 machineType);

    event MachineBorrowed(address who, string machineId, uint256 tokenId, uint256 borrowedAt, uint256 during);

    event MachineRenewed(address who, string machineId, uint256 tokenId, uint256 duration);

    constructor(address _prover) {
        prover = _prover;
    }

    function setProver(address _prover) public onlyRole(DEFAULT_ADMIN_ROLE) {
        prover = _prover;
    }

    function setPassManagerAddress(uint256 machineType, address passManagerAddress) external onlyRole(DEFAULT_ADMIN_ROLE) {
        passManagerAddresses[machineType] = passManagerAddress;
    }

    function lendMachine(string memory machineId, uint256 machineType, bytes memory signature) public {
        if (machines[machineId].machineType != 0) {
            revert RepeatedMachineLending();
        }

        if (passManagerAddresses[machineType] == address(0)) {
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

    function borrowMachine(address to, string memory machineId, uint256 tokenId) public {
        if (to == address(0)) {
            revert InvalidToAddress(to);
        }

        Machine storage machine = machines[machineId];
        if (machine.machineType == 0) {
            revert InvalidMachineId();
        }

        if (machine.borrowedAt + machine.duration > block.timestamp) {
            revert RepeatedMachineBorrowing();
        }

        address passManagerAddress = passManagerAddresses[machine.machineType];

        if (IERC721(passManagerAddress).ownerOf(tokenId) != msg.sender) {
            revert InvalidPassOwner(passManagerAddress);
        }

        IERC721(passManagerAddress).transferFrom(msg.sender, address(this), tokenId);

        uint256 duration = IMachinePassManager(passManagerAddress).getPassDuration(tokenId);

        machines[machineId] = Machine(machine.machineType, block.timestamp, duration, to);

        emit MachineBorrowed(to, machineId, tokenId, block.timestamp, duration);
    }

    function renewMachine(string memory machineId, uint256 tokenId) public {
        Machine storage machine = machines[machineId];
        if (machine.machineType == 0) {
            revert InvalidMachineId();
        }

        if (machine.borrowedAt + machine.duration < block.timestamp) {
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
}
