// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @title IYieldPassManager
/// @notice Interface for YieldPassManager contract
interface IYieldPassManager {
    /* ----------------------- Events ------------------------ */

    /// @notice Emitted when a new round is created
    event RoundCreated(uint256 indexed roundId, address creator);

    /// @notice Emitted when passes are minted
    event PassMinted(uint256 indexed roundId, address to, uint256 quantity);

    /// @notice Emitted when minters are updated for a round
    event MintersUpdated(uint256 indexed roundId, address[] addresses, bool status);

    /* ----------------------- Functions ------------------------ */

    /// @notice Returns the total number of rounds created
    /// @return The round count
    function roundCount() external view returns (uint256);

    /// @return The number of passes minted in a round
    function rounds(uint256 roundId) external view returns (address, uint256);

    /// @notice Creates a new pass selling round
    function createRound() external;

    /// @notice Grants or revokes minting permission for an address
    /// @param roundId The ID of the round
    /// @param addresses The address to update permissions for
    /// @param status True to grant minting permission, false to revoke
    function setMinters(uint256 roundId, address[] calldata addresses, bool status) external;

    /// @notice Mints passes for a specific round
    /// @param roundId The ID of the round to mint passes for
    /// @param to The address to mint passes to
    /// @param quantity The number of passes to mint
    function mint(uint256 roundId, address to, uint256 quantity) external;

    /// @notice Checks if an address is an authorized minter for a round
    /// @param roundId The ID of the round
    /// @param minter The address to check
    /// @return bool Whether the address is an authorized minter
    function isMinter(uint256 roundId, address minter) external view returns (bool);
}
