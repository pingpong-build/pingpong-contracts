// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {FutureFactory} from "../src/FutureFactory.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockERC20 is ERC20 {
    constructor(string memory _mockName, string memory _mockSymbol) ERC20(_mockName, _mockSymbol) {
        _mint(msg.sender, 1000000 * 10**decimals());
    }
}

contract FutureFactoryTest is Test {

    event FutureCreateID(uint256 indexed futureId);
    
    FutureFactory public factory;
    MockERC20 public usdt;
    MockERC20 public deliverable;
    address public owner;
    address public user1;
    address public user2;
    address public fundCollector;

    function setUp() public {
        owner = address(this);
        user1 = address(0x1);
        user2 = address(0x2);
        fundCollector = address(0x3);

        usdt = new MockERC20("Mock USDT", "mUSDT");
        deliverable = new MockERC20("Mock Deli", "mDeli");
        factory = new FutureFactory(fundCollector, "https://example.com/metadata/");

        // Transfer some USDT to users for testing
        usdt.transfer(user1, 10000 * 10**usdt.decimals());
        usdt.transfer(user2, 10000 * 10**usdt.decimals());
    }

    function testCreateFuture() public {
        factory.createFuture(address(deliverable), 1000, 100, address(usdt), 
            99 * 10**usdt.decimals(), 30, 9990 * 10**usdt.decimals(),
            block.timestamp + 1 seconds, 
            block.timestamp + 1 hours,
            block.timestamp + 2 hours);
        (uint256 _futureId,
            address _deliverable, 
            uint256 _deliverableQuantity, 
            uint256 _totalSupply,
            address _payToken,
            uint256 _price,
            uint256 _securityDepositRate,
            uint256 _securityDeposit,
            uint256 _startTime,
            uint256 _startDeliveryTime,
            uint256 _endTime,
            address _creator) = factory.futureMetas(1);
        
        (uint256 _totalDelivered,
            uint256 _totalClaimed,
            bool _hasDeposit,
            uint256 _mintedCount) = factory.futureStates(1);

        emit FutureCreateID(_futureId);
    }
}