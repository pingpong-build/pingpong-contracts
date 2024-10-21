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
        uint256 securityDeposit;           // The security deposit amount, denominated in payToken
        uint256 startTime;                 // The start time of the future
        uint256 startDeliveryTime;         // The start time for delivery
        uint256 endTime;                   // The end time of the future
        address owner;                     // The owner of the future
        uint256 feeRate;                   // The fee rate for the platform
    }

    /// @notice Struct to store information about each future
    struct FutureState {
        uint256 totalDelivered;            // The total quantity delivered so far
        uint256 totalClaimed;              // The total claimed revenue
        bool hasDeposit;                   // Indicates whether the security deposit has been paid
        uint256 mintedCount;               // The number of NFTs minted so far
    }

    /// @notice Mapping of future ID to Future struct
    mapping(uint256 => FutureState) public futureStates;

    /// @notice Mapping of future ID to FutureMeta struct
    mapping(uint256 => FutureMeta) public futureMetas;

    /* ----------------------- Events ------------------------ */

    /// @notice Event emitted when the fee rate is updated
    event FeeRateUpdated(uint256 feeRate);

    /// @notice Event emitted when a future is created
    event FutureCreate(uint256 indexed futureId, address deliverable, uint256 deliverableQuantity, 
        uint256 totalSupply, address payToken, uint256 price, uint256 securityDeposit,
        uint256 startTime, uint256 startDeliveryTime, uint256 endTime, address owner, uint256 feeRate);

    /// @notice Event emitted when a future is deposited
    event FutureDeposited(uint256 indexed futureId);

    /// @notice Event emitted when a future is minted
    event FutureMint(uint256 indexed futureId, address buyer, uint256 quantity);

    /// @notice Event emitted when a future is delivered
    event FutureDelivered(uint256 indexed futureId, uint256 quantity);

    /// @notice Event emitted when a future delivery is claimed
    event FutureDeliveryClaimed(uint256 indexed futureId, address seller, uint256 quantity, uint256 fee);

    /// @notice Event emitted when a future is claimed
    event FutureClaimed(uint256 indexed futureId, address buyer, uint256 quantity, uint256 claimDeliverable, uint256 securityDeposit, uint256 revertCost);

    /// @notice Event emitted when a future is refunded
    event FutureRefunded(uint256 indexed futureId);

    /* ----------------------- Errors ------------------------ */

    /// @notice Error thrown when the fee rate is invalid
    error InvalidFeeRate();

    /// @notice Error thrown when an invalid address is provided
    error InvalidAddress();

    /// @notice Error thrown when ERC20 transfer fails
    error ERC20TransferFailed();

    /// @notice Error thrown when the transfer fails
    error TransferFailed();

    /// @notice Error thrown when the token is invalid
    error InvalidToken();

    /// @notice Error thrown when the future time is invalid
    error InvalidFutureTime();

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
        
        setFeeRate(1); // default fee rate is 1%
    }

    /* ----------------------- Admin Functions ------------------------ */

    /// @notice Set the fee rate for the platform
    /// @param _feeRate The fee rate for the platform
    function setFeeRate(uint256 _feeRate) public onlyRole(OPERATOR_ROLE) {
        if (_feeRate > 100) {
            revert InvalidFeeRate();
        }
        feeRate = _feeRate;

        emit FeeRateUpdated(_feeRate);
    }

    /* ----------------------- Public Functions ------------------------ */

    /// @notice Create a new future
    /// @param _deliverable The address of the deliverable ERC20 token
    /// @param _deliverableQuantity The quantity of deliverable per NFT
    /// @param _totalSupply The total supply of future NFTs
    /// @param _payToken The address of payment token
    /// @param _price The price of the future NFT, denominated in payToken
    /// @param _securityDeposit The security deposit amount, denominated in payToken
    /// @param _startTime The start time of the future
    /// @param _startDeliveryTime The start time for delivery
    /// @param _endTime The end time of the future
    /// @param _owner The owner of the future
    function createFuture(
        address _deliverable,
        uint256 _deliverableQuantity,
        uint256 _totalSupply,
        address _payToken,
        uint256 _price,
        uint256 _securityDeposit,
        uint256 _startTime,
        uint256 _startDeliveryTime,
        uint256 _endTime,
        address _owner
    ) external {
        if (_startTime < block.timestamp || _endTime <= _startTime || 
            _startDeliveryTime <= _startTime || _startDeliveryTime >= _endTime) {
            revert InvalidFutureTime();
        }

        if (_deliverable == address(0) || _payToken == address(0)) {
            revert InvalidToken();
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
        newFutureMeta.securityDeposit = _securityDeposit;
        newFutureMeta.startTime = _startTime;
        newFutureMeta.startDeliveryTime = _startDeliveryTime;
        newFutureMeta.endTime = _endTime;
        newFutureMeta.owner = _owner;
        newFutureMeta.feeRate = feeRate;
        
        newFutureState.totalDelivered = 0;
        newFutureState.totalClaimed = 0;
        newFutureState.hasDeposit = false;
        newFutureState.mintedCount = 0;

        emit FutureCreate(futureCount, _deliverable, _deliverableQuantity, _totalSupply, _payToken, _price,
            _securityDeposit, _startTime, _startDeliveryTime, _endTime, _owner, feeRate); 
    }

    /// @notice Deposit the security deposit for a future
    /// @param _futureId The ID of the future
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
    /// @param _futureId The ID of the future
    /// @param _quantity The quantity of future NFTs to mint
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
    /// @param _futureId The ID of the future
    /// @param _quantity The quantity of deliverables to submit
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
    /// @param _futureId The ID of the future
    function deliverClaim(uint256 _futureId) external nonReentrant {
        FutureMeta memory futureMeta = futureMetas[_futureId];
        FutureState storage futureState = futureStates[_futureId];
        if (msg.sender != futureMeta.owner) {
            revert InvalidAddress();
        }

        uint256 totalCanClaim = futureMeta.price * futureState.totalDelivered / futureMeta.deliverableQuantity;
        uint256 totalMintedValt = futureMeta.price * futureState.mintedCount;
        if (totalCanClaim > totalMintedValt) {
            totalCanClaim = totalMintedValt;
        }
        if (totalCanClaim < futureState.totalClaimed) {
            revert InvalidFutureClaim();
        }
        uint256 canClaim = totalCanClaim - futureState.totalClaimed;
        uint256 fee = futureMeta.feeRate * canClaim / 100;
        uint256 realCanClaim = canClaim - fee;

        if (futureMeta.payToken == address(0)) {
            (bool successClaim, ) = msg.sender.call{value: realCanClaim}("");
            if (!successClaim) {
                revert TransferFailed();
            }
            (bool successFee, ) = fundCollector.call{value: fee}("");
            if (!successFee) {
                revert TransferFailed();
            }
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
    /// @param _futureId The ID of the future
    /// @param _claimCount The quantity of future NFTs to claim
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
        uint256 claimDeliverable = 0;
        uint256 securityDeposit = 0;
        uint256 revertCost = 0;
        if (futureState.totalDelivered < totalNeedDelivered) {
            uint256 deliveryRate = futureState.totalDelivered * 100 / totalNeedDelivered;
            claimDeliverable = _claimCount * futureMeta.deliverableQuantity * deliveryRate / 100;

            securityDeposit = _claimCount * futureMeta.securityDeposit / futureMeta.totalSupply;
            revertCost = _claimCount * futureMeta.price * (100 - deliveryRate) / 100;
            if (futureMeta.payToken == address(0)) {
                (bool securityTransfer, ) = msg.sender.call{value: securityDeposit}("");
                if (!securityTransfer) {
                    revert TransferFailed();
                }
                (bool costTransfer, ) = msg.sender.call{value: revertCost}("");
                if (!costTransfer) {
                    revert TransferFailed();
                }
            } else {
                bool securityTransfer = IERC20(futureMeta.payToken).transfer(msg.sender, securityDeposit);
                if (!securityTransfer) {
                    revert ERC20TransferFailed();
                }
                bool costTransfer = IERC20(futureMeta.payToken).transfer(msg.sender, revertCost);
                if (!costTransfer) {
                    revert ERC20TransferFailed();
                }
            }
        } else {
            claimDeliverable = _claimCount * futureMeta.deliverableQuantity;
        }
        bool deliverTransfer = IERC20(futureMeta.deliverable).transfer(msg.sender, claimDeliverable);
        if (!deliverTransfer) {
            revert ERC20TransferFailed();
        }

        _burn(msg.sender, _futureId, _claimCount);

        emit FutureClaimed(_futureId, msg.sender, _claimCount, claimDeliverable, securityDeposit, revertCost);
    }

    /// @notice Refund future
    /// @param _futureId The ID of the future
    function refund(uint256 _futureId) external nonReentrant {
        FutureMeta memory futureMeta = futureMetas[_futureId];
        FutureState storage futureState = futureStates[_futureId];
        if (futureMeta.endTime > block.timestamp) {
            revert InvalidFutureClaim();
        }
        if (futureState.hasDeposit == false) {
            revert DepositNotPaid();
        }
        if (msg.sender != futureMeta.owner) {
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
            (bool securityTransfer, ) = msg.sender.call{value: returnSecurityDeposit}("");
            if (!securityTransfer) {
                revert TransferFailed();
            }
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
    /// @param _futureId The ID of the future
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
