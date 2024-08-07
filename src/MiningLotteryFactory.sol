// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";

/// @title MiningLotteryHub
/// @notice This contract manages a continuous mining-related lottery system with multiple rounds
/// @dev Uses Chainlink VRF for randomness and issues NFTs as lottery tickets
contract MiningLotteryFactory is ERC721, VRFConsumerBaseV2Plus {
    using SafeERC20 for IERC20;

    /* ----------------------- Structs ------------------------ */

    /// @notice Struct to store information about each lottery round
    struct Round {
        uint256 startTime;        // Start time of the round
        uint256 endTime;          // End time of the round
        uint256 pricePerTicket;   // Price of each ticket in USDT
        uint256 totalRange;
        uint256 winningRange;     // Winning range (0 to this number will win)
        uint256 ticketsSold;      // Number of tickets sold in this round
        uint256 miningDays;       // Number of days of mining revenue this round represents
    }

    /// @notice Struct to store information about each lottery ticket
    struct Ticket {
        uint256 roundId;          // ID of the round this ticket belongs to
        bool resultDetermined;    // Whether the result has been determined
        uint256 randomNumber;     // The random number generated for this ticket
        bool won;                 // Whether this ticket won
    }

    /* ----------------------- Events ------------------------ */

    /// @notice Emitted when a new round is created
    event RoundCreated(uint256 indexed roundId, uint256 startTime, uint256 endTime, uint256 pricePerTicket, uint256 miningDays);

    /// @notice Emitted when a share is minted
    event ShareMinted(uint256 indexed roundId, address indexed buyer, uint256 shareId);

    /// @notice Emitted when the revenue collector address is updated
    event FundCollectorUpdated(address newCollector);

    /// @notice Emitted when a ticket is purchased
    event TicketMinted(uint256 indexed ticketId, address buyer, uint256 indexed roundId);

    /// @notice Emitted when a ticket result is determined
    event TicketResultDetermined(uint256 indexed ticketId, uint256 indexed roundId, uint256 randomNumber, bool won);


    /* ----------------------- Errors ------------------------ */

    /// @notice Error thrown when minting is not active
    error MintingNotActive();

    /// @notice Error thrown when all shares have been minted
    error AllSharesMinted();

    /// @notice Error thrown when a non-whitelisted address tries to mint during whitelist period
    error NotInWhitelist();

    /// @notice Error thrown when an invalid share ID is provided
    error InvalidShareId();

    error RequestIdNotFound();

    /* ----------------------- Storage ------------------------ */

    // Depends on the number of requested values that you want sent to the
    // fulfillRandomWords() function. Storing each word costs about 20,000 gas,
    // so 100,000 is a safe default for this example contract. Test and adjust
    // this limit based on the network that you select, the size of the request,
    // and the processing of the callback request in the fulfillRandomWords()
    // function.
    uint32 public callbackGasLimit = 100000;

    // The default is 3, but you can set this higher.
    uint16 public requestConfirmations = 3;

    // For this example, retrieve 2 random values in one request.
    // Cannot exceed VRFCoordinatorV2_5.MAX_NUM_WORDS.
    uint32 public numWords = 2;

    /// @notice USDT token contract
    IERC20 public immutable usdtToken;

    /// @notice Chainlink VRF subscription ID
    uint64 private immutable s_subscriptionId;

    /// @notice Chainlink VRF key hash
    bytes32 private immutable s_keyHash;

    /// @notice Total number of rounds created
    uint256 public roundCount;

    /// @notice Address to collect the revenue
    address public fundCollector;

    /// @notice Mapping of round ID to RevenueRound struct
    mapping(uint256 => Round) public rounds;

    /// @notice Mapping from ticket ID to Ticket struct
    mapping(uint256 => Ticket) public tickets;

    /// @notice Mapping from ticket ID to VRF request ID
    mapping(uint256 => uint256) public ticketToRequestId;

    /// @notice Mapping from VRF request ID to ticket ID
    mapping(uint256 => uint256) public requestIdToTicketId;

    /// @notice Contract constructor
    /// @param _usdtToken Address of the USDT token contract
    /// @param _vrfCoordinator Address of the Chainlink VRF Coordinator
    /// @param _subscriptionId Chainlink VRF subscription ID
    /// @param _keyHash Chainlink VRF key hash
    constructor(
        address _usdtToken,
        address _vrfCoordinator,
        uint64 _subscriptionId,
        bytes32 _keyHash
    )
    ERC721("Mining Lottery Ticket", "MLT")
    VRFConsumerBaseV2Plus(_vrfCoordinator)
    {
        usdtToken = IERC20(_usdtToken);
        s_subscriptionId = _subscriptionId;
        s_keyHash = _keyHash;
    }

    /// @notice Create a new lottery round
    /// @param _startTime Start time of the round
    /// @param _endTime End time of the round
    /// @param _ticketPrice Price of each ticket in USDT
    /// @param _winningRange Winning range (0 to this number will win)
    /// @param _miningDays Number of days of mining revenue this round represents
    function createRound(
        uint256 _startTime,
        uint256 _endTime,
        uint256 _ticketPrice,
        uint256 _totalRange,
        uint256 _winningRange,
        uint256 _miningDays
    ) external onlyOwner {
        roundCount++;
        Round storage newRound = rounds[roundCount];
        newRound.pricePerTicket = _ticketPrice;
        newRound.startTime = _startTime;
        newRound.endTime = _endTime;
        newRound.totalRange = _totalRange;
        newRound.winningRange = _winningRange;
        newRound.miningDays = _miningDays;

        emit RoundCreated(roundCount, _startTime, _endTime, _ticketPrice, _miningDays);
    }

    function mintTicket(uint256 _roundId) external {
        Round storage round = rounds[_roundId];
        if (block.timestamp < round.startTime || block.timestamp > round.endTime) {
            revert MintingNotActive();
        }

        usdtToken.safeTransferFrom(msg.sender, address(this), round.pricePerTicket);

        uint256 newTicketId = round.ticketsSold + 1;
        _safeMint(msg.sender, newTicketId);

        tickets[newTicketId] = Ticket({
            roundId: _roundId,
            resultDetermined: false,
            randomNumber: 0,
            won: false
        });

        round.ticketsSold++;

        requestRandomness(newTicketId);

        emit TicketMinted(newTicketId, msg.sender, _roundId);
    }

    /* ----------------------- Internal Functions ------------------------ */

    /// @notice Request randomness for a ticket
    /// @param _ticketId The ID of the ticket to request randomness for
    function requestRandomness(uint256 _ticketId) internal {
        uint256 requestId = s_vrfCoordinator.requestRandomWords(
            VRFV2PlusClient.RandomWordsRequest({
                keyHash: s_keyHash,
                subId: s_subscriptionId,
                requestConfirmations: requestConfirmations,
                callbackGasLimit: callbackGasLimit,
                numWords: numWords,
                extraArgs: VRFV2PlusClient._argsToBytes(
                    VRFV2PlusClient.ExtraArgsV1({nativePayment: false})
                )
            })
        );

        ticketToRequestId[_ticketId] = requestId;
        requestIdToTicketId[requestId] = _ticketId;
    }

    /// @notice Callback function used by VRF Coordinator
    /// @param requestId The ID of the request
    /// @param randomWords The array of random results from VRF Coordinator
    function fulfillRandomWords(uint256 requestId, uint256[] calldata randomWords) internal override {
        uint256 ticketId = requestIdToTicketId[requestId];
        if (ticketId == 0) revert RequestIdNotFound();

        Ticket storage ticket = tickets[ticketId];
        Round storage round = rounds[ticket.roundId];

        uint256 randomNumber = randomWords[0] % round.totalRange;
        ticket.randomNumber = randomNumber;
        ticket.won = randomNumber <= round.winningRange;
        ticket.resultDetermined = true;

        emit TicketResultDetermined(ticketId, ticket.roundId, randomNumber, ticket.won);
    }
}
