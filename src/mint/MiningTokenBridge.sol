// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {MiningToken} from "./MiningToken.sol";
import {Constants} from "../libraries/Constants.sol";
import {Errors} from "../libraries/Errors.sol";

/// @title MiningTokenBridge
/// @notice A contract to bridge tokens from Ethereum to other chains
/// @dev The contract is used to bridge tokens from Ethereum to other chains
contract MiningTokenBridge is AccessControl, ReentrancyGuard {

    /// @notice Chain ID
    string public originalChainID;

    /// @notice Operator
    address public fundCollector;

    /// @notice Fee rate
    /// Fee rate, measured in per 1e8, e.g. 1e6 means 1%, 1e5 means 0.1%
    uint32 public feeRate = 0;

    /// @notice Bridge ID
    uint256 public bridgeID;

    /// @notice Bridge ID is handled
    mapping(bytes32 => bool) public handledBridgeIDs;

    /// @notice Event emitted when the fund collector is changed
    /// @param fundCollector Address of the fund collector
    event FundCollectorChanged(address fundCollector);

    /// @notice Event emitted when the fee rate is changed
    /// @param feeRate Fee rate
    event FeeRateChanged(uint32 feeRate);
    
    /// @notice Event emitted when tokens are bridged
    /// @param bid Bridge ID
    /// @param cid Chain ID
    /// @param token Address of the token
    /// @param bridgeFrom Address of the bridge from
    /// @param bridgeTo Address of the bridge to
    /// @param amount Amount of tokens bridged
    /// @param fee Fee
    event Bridged(bytes32 bid, string indexed cid, address indexed token, address indexed bridgeFrom, string bridgeTo, uint256 amount, uint256 fee);

    /// @notice Event emitted when tokens are released
    /// @param token Address of the token
    /// @param to Address of the recipient
    /// @param amount Amount of tokens released
    event Released(bytes32 bid, address indexed token, address indexed to, uint256 amount);

    /// @notice Event emitted when tokens are minted
    /// @param token Address of the token
    /// @param to Address of the recipient
    /// @param amount Amount of tokens minted
    event Minted(bytes32 bid, address indexed token, address indexed to, uint256 amount);

    /// @notice Error emitted when the bridge ID is invalid
    error InvalidBridgeID();

    /// @notice Initialize the contract
    /// @param _operator Address of the operator
    constructor(string memory _originalChainID, address _operator, address _fundCollector, uint32 _feeRate) {
        fundCollector = _fundCollector;
        feeRate = _feeRate;
        originalChainID = _originalChainID;
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(Constants.OPERATOR_ROLE, _operator);

        emit FundCollectorChanged(fundCollector);
        emit FeeRateChanged(feeRate);
    }

    /// @notice Set the fund collector
    /// @param _fundCollector Address of the fund collector
    function setFundCollector(address _fundCollector) public onlyRole(Constants.OPERATOR_ROLE) {
        fundCollector = _fundCollector;
        emit FundCollectorChanged(fundCollector);
    }

    /// @notice Set the fee rate
    /// @param _feeRate Fee rate
    function setFeeRate(uint32 _feeRate) public onlyRole(Constants.OPERATOR_ROLE) {
        feeRate = _feeRate;
        emit FeeRateChanged(feeRate);
    }

    /// @notice Bridge tokens from Ethereum to other chains
    /// @param cid Chain ID
    /// @param token Address of the token
    /// @param bridgeTo Address of the bridge
    /// @param amount Amount of tokens to bridge
    function bridge(string memory cid, address token, string memory bridgeTo, uint256 amount) external payable nonReentrant {
        bytes32 bid = keccak256(abi.encodePacked(originalChainID, cid, msg.sender, block.number, block.timestamp, bridgeID));
        bridgeID++;
        if (token == address(0)) {
            if (msg.value == 0) revert Errors.InvalidAmount();
            uint256 fee = msg.value * feeRate / 1e8;
            uint256 amountAfterFee = msg.value - fee;
            (bool success, ) = fundCollector.call{value: fee}("");
            if (!success) revert Errors.TransferFailed();
            emit Bridged(bid, cid, token, msg.sender, bridgeTo, amountAfterFee, fee);
        } else {
            if (amount == 0) revert Errors.InvalidAmount();
            uint256 fee = amount * feeRate / 1e8;
            uint256 amountAfterFee = amount - fee;
            IERC20 tokenContract = IERC20(token);
            bool success = tokenContract.transferFrom(msg.sender, address(this), amountAfterFee);
            if (!success) revert Errors.TransferFailed();
            success = tokenContract.transferFrom(msg.sender, fundCollector, fee);
            if (!success) revert Errors.TransferFailed();
            emit Bridged(bid, cid, token, msg.sender,bridgeTo, amountAfterFee, fee);
        }
    }

    /// @notice Release tokens
    /// @param bid Bridge ID
    /// @param token Address of the token
    /// @param to Address of the recipient
    /// @param amount Amount of tokens to release
    function release(bytes32 bid, address token, address to, uint256 amount) external onlyRole(Constants.OPERATOR_ROLE) nonReentrant {
        if (handledBridgeIDs[bid]) revert InvalidBridgeID();
        if (to == address(0)) revert Errors.InvalidAddress();
        handledBridgeIDs[bid] = true;
        if (token == address(0)) {
            // need EOA to receive
            (bool success, ) = to.call{value: amount, gas: 1e5}("");
            if (!success) revert Errors.TransferFailed();
        } else {
            IERC20 tokenContract = IERC20(token);
            bool success = tokenContract.transferFrom(address(this), to, amount);
            if (!success) revert Errors.TransferFailed();
        }
        emit Released(bid, token, to, amount);
    }
    
    /// @notice Mint tokens
    /// @param bid Bridge ID
    /// @param token Address of the token
    /// @param to Address of the recipient
    /// @param amount Amount of tokens to mint
    function mint(bytes32 bid, address token, address to, uint256 amount) external onlyRole(Constants.OPERATOR_ROLE) nonReentrant {
        if (handledBridgeIDs[bid]) revert InvalidBridgeID();
        if (token == address(0) || to == address(0)) {
            revert Errors.InvalidAddress();
        }
        handledBridgeIDs[bid] = true;
        MiningToken tokenContract = MiningToken(token);
        tokenContract.mint(to, amount);

        emit Minted(bid, token, to, amount);
    }
}