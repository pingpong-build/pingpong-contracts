// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {ERC1155} from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";

/// @title FutureFactory
/// @notice This contract manages the minting and management of future NFTs
/// @dev Inherits from ERC1155 and AccessControl
contract FutureFactory is ERC1155, AccessControl, ReentrancyGuard {
    using Strings for uint256;

    /* ----------------------- Constants ------------------------ */

    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");

    /* ----------------------- Storage ------------------------ */

    /// @notice Address to collect the revenue
    address public fundCollector;

    /// @notice Fee rate for the platform
    uint256 public feeRate;

    /// @notice Total number of futures created
    uint256 public futureCount;

    struct FutureMeta {
        uint256 futureId;                  // The ID of the future
        address deliverable;               // The address of the deliverable ERC20 token
        uint256 deliverableQuantity;       // The quantity of deliverable per NFT
        uint256 totalSupply;               // The total supply of future NFTs
        address payToken;                  // The type of payment token (used for margin and purchasing the future)
        uint256 price;                     // The price of the future NFT, denominated in payToken
        uint256 securityDepositRate;       // The security deposit rate, ranging from 0 to 100
        uint256 securityDeposit;           // The security deposit amount, denominated in payToken
        uint256 startTime;                 // The start time of the future
        uint256 startDeliveryTime;         // The start time for delivery
        uint256 endTime;                   // The end time of the future
        address creator;                   // The creator of the future
    }

    /// @notice Struct to store information about each future
    struct FutureState {
        uint256 totalDelivered;            // The total quantity delivered so far
        uint256 totalClaimed;                // The total claimed revenue
        bool hasDeposit;                   // Indicates whether the security deposit has been paid
        uint256 mintedCount;               // The number of NFTs minted so far
    }

    /// @notice Mapping of future ID to Future struct
    mapping(uint256 => FutureState) public futureStates;

    mapping(uint256 => FutureMeta) public futureMetas;

    /* ----------------------- Events ------------------------ */

    event FeeRateUpdated(uint256 feeRate);

    event FutureCreate(uint256 indexed futureId, address deliverable, uint256 deliverableQuantity, 
        uint256 totalSupply, address payToken, uint256 price, uint256 securityDepositRate, uint256 securityDeposit,
        uint256 startTime, uint256 startDeliveryTime, uint256 endTime, address creator);

    event FutureDeposited(uint256 indexed futureId);

    event FutureMint(uint256 indexed futureId, address buyer, uint256 quantity);

    event FutureDelivered(uint256 indexed futureId, uint256 quantity);

    event FutureDeliveryClaimed(uint256 indexed futureId, address seller, uint256 quantity, uint256 fee);

    event FutureClaimed(uint256 indexed futureId, address buyer, uint256 quantity);

    event FutureRefunded(uint256 indexed futureId);

    /* ----------------------- Errors ------------------------ */

    /// @notice Error thrown when an invalid address is provided
    error InvalidAddress();

    /// @notice Error thrown when ERC20 transfer fails
    error ERC20TransferFailed();

    /// @notice Error thrown when the token is invalid
    error InvalidToken();

    /// @notice Error thrown when the future time is invalid
    error InvalidFutureTime();

    /// @notice Error thrown when the future security deposit is invalid
    error InvalidFutureSecurityDeposit();

    /// @notice Error thrown when the deposit is not paid
    error DepositNotPaid();

    /// @notice Error thrown when the deposit is already paid
    error DepositAlreadyPaid();

    /// @notice Error thrown when the future is not active
    error FutureNotActive();

    /// @notice Error thrown when mint future has not enough pay token
    error MintingNotEnoughPayToken();

    /// @notice Error thrown when the future is insufficient
    error InsufficientFuture();

    /// @notice Error thrown when the future claim is invalid
    error InvalidFutureClaim();

    /* ----------------------- Constructor ------------------------ */

    /// @notice Constructor to initialize the contract
    /// @param _fundCollector Address to collect the revenue
    /// @param _uri Base URI for the future NFTs
    constructor(address _fundCollector, string memory _uri) ERC1155(_uri) {
        if (_fundCollector == address(0)) {
            revert InvalidAddress();
        }

        fundCollector = _fundCollector;

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(OPERATOR_ROLE, msg.sender);
    }

    /* ----------------------- Admin Functions ------------------------ */

    function setFeeRate(uint256 _feeRate) external onlyRole(OPERATOR_ROLE) {
        feeRate = _feeRate;

        emit FeeRateUpdated(_feeRate);
    }

    /* ----------------------- Public Functions ------------------------ */

    /// @notice Create a new future
    /// @param _deliverable The address of the deliverable ERC20 token
    /// @param _deliverableQuantity The quantity of deliverable per NFT
    /// @param _totalSupply The total supply of future NFTs
    function createFuture(
        address _deliverable,
        uint256 _deliverableQuantity,
        uint256 _totalSupply,
        address _payToken,
        uint256 _price,
        uint256 _securityDepositRate,
        uint256 _securityDeposit,
        uint256 _startTime,
        uint256 _startDeliveryTime,
        uint256 _endTime
    ) external {
        if (_startTime < block.timestamp || _endTime <= _startTime || 
            _startDeliveryTime <= _startTime || _startDeliveryTime >= _endTime) {
            revert InvalidFutureTime();
        }

        if (_deliverable == address(0) || _payToken == address(0)) {
            revert InvalidToken();
        }

        if (_securityDepositRate < 0 || _securityDepositRate > 100 || _securityDeposit < 0) {
            revert InvalidFutureSecurityDeposit();
        }

        futureCount++;
        FutureState storage newFutureState = futureStates[futureCount];
        FutureMeta storage newFutureMeta = futureMetas[futureCount];
        newFutureMeta.futureId = futureCount;
        newFutureMeta.deliverable = _deliverable;
        newFutureMeta.deliverableQuantity = _deliverableQuantity;
        newFutureMeta.totalSupply = _totalSupply;
        newFutureMeta.payToken = _payToken;
        newFutureMeta.price = _price;
        newFutureMeta.securityDepositRate = _securityDepositRate;
        newFutureMeta.securityDeposit = _securityDeposit;
        newFutureMeta.startTime = _startTime;
        newFutureMeta.startDeliveryTime = _startDeliveryTime;
        newFutureMeta.endTime = _endTime;
        newFutureMeta.creator = msg.sender;
        
        newFutureState.totalDelivered = 0;
        newFutureState.totalClaimed = 0;
        newFutureState.hasDeposit = false;
        newFutureState.mintedCount = 0;

        emit FutureCreate(futureCount, _deliverable, _deliverableQuantity, _totalSupply, _payToken, _price,
            _securityDepositRate, _securityDeposit, _startTime, _startDeliveryTime, _endTime, msg.sender); 
    }

    /// @notice Deposit the security deposit for a future
    function deposit(uint256 _futureId) external payable {
        FutureMeta memory futureMeta = futureMetas[_futureId];
        FutureState storage futureState = futureStates[_futureId];
        if (futureMeta.endTime < block.timestamp) {
            revert FutureNotActive();
        }
        if (futureState.hasDeposit) {
            revert DepositAlreadyPaid();
        }

        if (futureMeta.payToken == address(0)) {
            if (msg.value < futureMeta.securityDeposit) {
                revert DepositNotPaid();
            }
        } else {
            if (IERC20(futureMeta.payToken).balanceOf(msg.sender) < futureMeta.securityDeposit) {
                revert DepositNotPaid();
            }
            bool success = IERC20(futureMeta.payToken).transferFrom(msg.sender, address(this), futureMeta.securityDeposit);
            if (!success) {
                revert DepositNotPaid();
            }
        }
        futureState.hasDeposit = true;

        emit FutureDeposited(_futureId);
    }

    /// @notice Mint future NFTs
    function mint(uint256 _futureId, uint256 _quantity) external payable nonReentrant {
        FutureMeta memory futureMeta = futureMetas[_futureId];
        FutureState storage futureState = futureStates[_futureId];
        if (futureMeta.startTime > block.timestamp || futureMeta.startDeliveryTime < block.timestamp) {
            revert FutureNotActive();
        }
        if (futureState.hasDeposit == false) {
            revert DepositNotPaid();
        }
        if (futureState.mintedCount + _quantity > futureMeta.totalSupply) {
            revert InsufficientFuture();
        }

        uint256 totalCost = futureMeta.price * _quantity;
        if (futureMeta.payToken == address(0)) {
            if (msg.value < totalCost) {
                revert MintingNotEnoughPayToken();
            }
        } else {
            if (IERC20(futureMeta.payToken).balanceOf(msg.sender) < totalCost) {
                revert MintingNotEnoughPayToken();
            }
            bool success = IERC20(futureMeta.payToken).transferFrom(msg.sender, address(this), totalCost);
            if (!success) {
                revert ERC20TransferFailed();
            }
        }

        _mint(msg.sender, _futureId, _quantity, "");
        futureState.mintedCount += _quantity;

        emit FutureMint(_futureId, msg.sender, _quantity);
    }

    /// @notice Submit deliverables, and pay fee, can submit multiple times
    function deliver(uint256 _futureId, uint256 _quantity) external {
        FutureMeta memory futureMeta = futureMetas[_futureId];
        FutureState storage futureState = futureStates[_futureId];
        if (futureMeta.startTime > block.timestamp || futureMeta.endTime < block.timestamp) {
            revert FutureNotActive();
        }
        bool success = IERC20(futureMeta.deliverable).transferFrom(msg.sender, address(this), _quantity);
        if (!success) {
            revert ERC20TransferFailed();
        }
        futureState.totalDelivered += _quantity;

        emit FutureDelivered(_futureId, _quantity);
    }

    /// @notice Deliver claim, can deliver multiple times
    function deliverClaim(uint256 _futureId) external nonReentrant {
        FutureMeta memory futureMeta = futureMetas[_futureId];
        FutureState storage futureState = futureStates[_futureId];
        if (msg.sender != futureMeta.creator) {
            revert InvalidAddress();
        }

        uint256 totalCanClaim = futureMeta.price * futureState.totalDelivered / futureMeta.deliverableQuantity;
        if (totalCanClaim < futureState.totalClaimed) {
            revert InvalidFutureClaim();
        }
        uint256 canClaim = totalCanClaim - futureState.totalClaimed;
        uint256 fee = feeRate * canClaim / 100;
        uint256 realCanClaim = canClaim - fee;

        if (futureMeta.payToken == address(0)) {
            payable(msg.sender).transfer(realCanClaim);
            payable(fundCollector).transfer(fee);
        } else {
            bool successClaim = IERC20(futureMeta.payToken).transfer(msg.sender, realCanClaim);
            if (!successClaim) {
                revert ERC20TransferFailed();
            }
            bool successFee = IERC20(futureMeta.payToken).transfer(fundCollector, fee);
            if (!successFee) {
                revert ERC20TransferFailed();
            }
        }
        futureState.totalClaimed += canClaim;

        emit FutureDeliveryClaimed(_futureId, msg.sender, canClaim, fee);
    }

    /// @notice Claim future, can claim multiple times
    function claim(uint256 _futureId, uint256 _claimCount) external nonReentrant {
        FutureMeta memory futureMeta = futureMetas[_futureId];
        FutureState memory futureState = futureStates[_futureId];
        if (futureMeta.endTime > block.timestamp) {
            revert InvalidFutureClaim();
        }

        uint256 totalCount = balanceOf(msg.sender, _futureId);
        if (totalCount < _claimCount) {
            revert InvalidFutureClaim();
        }

        uint256 totalNeedDelivered = futureMeta.deliverableQuantity * futureState.mintedCount;
        if (futureState.totalDelivered < totalNeedDelivered) {
            uint256 deliveryRate = futureMeta.deliverableQuantity * 100 / totalNeedDelivered;
            uint256 claimValt = _claimCount * futureMeta.deliverableQuantity * deliveryRate / 100;
            bool deliverTransfer = IERC20(futureMeta.deliverable).transfer(msg.sender, claimValt);
            if (!deliverTransfer) {
                revert ERC20TransferFailed();
            }

            uint256 securityDeposit = _claimCount * futureMeta.securityDeposit / futureMeta.totalSupply;
            uint256 totalCost = _claimCount * futureMeta.price * (100 - deliveryRate) / 100;
            if (futureMeta.payToken == address(0)) {
                payable(msg.sender).transfer(securityDeposit);
                payable(msg.sender).transfer(totalCost);
            } else {
                bool securityTransfer = IERC20(futureMeta.payToken).transfer(msg.sender, securityDeposit);
                if (!securityTransfer) {
                    revert ERC20TransferFailed();
                }
                bool costTransfer = IERC20(futureMeta.payToken).transfer(msg.sender, totalCost);
                if (!costTransfer) {
                    revert ERC20TransferFailed();
                }
            }
        } else {
            uint256 claimDeliverable = _claimCount * futureMeta.deliverableQuantity;
            bool deliverTransfer = IERC20(futureMeta.deliverable).transfer(msg.sender, claimDeliverable);
            if (!deliverTransfer) {
                revert ERC20TransferFailed();
            }
        }

        _burn(msg.sender, _futureId, _claimCount);

        emit FutureClaimed(_futureId, msg.sender, _claimCount);
    }

    /// @notice Refund future
    function refund(uint256 _futureId) external nonReentrant {
        FutureMeta memory futureMeta = futureMetas[_futureId];
        FutureState storage futureState = futureStates[_futureId];
        if (futureMeta.endTime > block.timestamp) {
            revert InvalidFutureClaim();
        }
        if (futureState.hasDeposit == false) {
            revert DepositNotPaid();
        }
        if (msg.sender != futureMeta.creator) {
            revert InvalidAddress();
        }

        uint256 totalNeedDelivered = futureMeta.deliverableQuantity * futureState.mintedCount;
        uint256 returnSecurityDeposit = 0;
        if (futureState.totalDelivered < totalNeedDelivered) {
            uint256 totalNeedSecurityDepoist = futureMeta.securityDeposit * futureState.mintedCount / futureMeta.totalSupply;
            returnSecurityDeposit = futureMeta.securityDeposit - totalNeedSecurityDepoist;
        } else {
            returnSecurityDeposit = futureMeta.securityDeposit;
        }

        if (futureMeta.payToken == address(0)) {
            payable(msg.sender).transfer(returnSecurityDeposit);
        } else {
            bool securityTransfer = IERC20(futureMeta.payToken).transfer(msg.sender, returnSecurityDeposit);
            if (!securityTransfer) {
                revert ERC20TransferFailed();
            }
        }

        if (futureState.totalDelivered > totalNeedDelivered) {
            uint256 claimDeliverable = futureState.totalDelivered - totalNeedDelivered;
            bool deliverableTransfer = IERC20(futureMeta.deliverable).transfer(msg.sender, claimDeliverable);
            if (!deliverableTransfer) {
                revert ERC20TransferFailed();
            }
        }
        futureState.hasDeposit = false;

        emit FutureRefunded(_futureId);
    }

    /* ----------------------- View functions ------------------------ */

    /// @notice Check if the future is delivered completely
    function confirmDelivery(uint256 _futureId) public view returns (bool) {
        FutureMeta memory futureMeta = futureMetas[_futureId];
        FutureState memory futureState = futureStates[_futureId];
        uint256 totalValt = futureMeta.deliverableQuantity * futureState.mintedCount;
        if (futureState.totalDelivered < totalValt) {
            return false;
        }
        return true;
    }

    /// @notice Get token URI of mining-pass
    /// @param _tokenId The pass NFT token id
    /// @return The token URI
    function uri(uint256 _tokenId) public view virtual override returns (string memory) {
        return string(abi.encodePacked(super.uri(_tokenId), _tokenId.toString()));
    }

    function supportsInterface(bytes4 interfaceId) public view override(ERC1155, AccessControl) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}
