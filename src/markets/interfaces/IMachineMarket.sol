// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

interface IMachineMarket {
    /**
      * @dev Define the machine struct
      * User can borrow machine conditions:
      * 1. borrower is empty
      * 2. borrower is not empty, updated is true and borrowedAt + duration < block.timestamp
     */
    struct Machine {
        uint256 machineType;
        uint256 borrowedAt;
        uint256 duration;
        address borrower;
        bool updated;
    }

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
    error RepeatedMachineListing();

    /**
     * @dev Thrown when the signer is not prover address
     */
    error InvalidSignature();

    /**
     * @dev Thrown when to address is empty
     */
    error InvalidToAddress();

    event MachineListed(string machineId, uint256 machineType);

    event MachineBorrowed(address to, string machineId, uint256 tokenId, uint256 during, string data);

    event MachineRenewed(address to, string machineId, uint256 tokenId, uint256 duration);

    function borrowMachine(address to, string memory machineId, uint256 tokenId, string memory data) external;

    function getMachineType(string memory machineId) external returns (uint256);

    function passManagerAddresses(uint256 machineType) external view returns (address);
}
