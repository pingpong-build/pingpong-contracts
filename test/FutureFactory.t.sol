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

    function testSetFeeRate() public {
        factory.setFeeRate(2);
        uint256 _feeRate = factory.feeRate();
        assertEq(_feeRate, 2);
    }

    function testCreateFuture() public {
        factory.createFuture(address(deliverable), 1000 * 10**deliverable.decimals(), 100, address(usdt), 
            99 * 10**usdt.decimals(), 9990 * 10**usdt.decimals(),
            block.timestamp + 1 seconds, 
            block.timestamp + 1 hours,
            block.timestamp + 2 hours,
            owner);
        (uint256 _futureId,
            address _deliverable, 
            uint256 _deliverableQuantity, 
            uint256 _totalSupply,
            address _payToken,
            uint256 _price,
            uint256 _securityDeposit,
            uint256 _startTime,
            uint256 _startDeliveryTime,
            uint256 _endTime,
            address _owner,
            uint256 _feeRate) = factory.futureMetas(1);
        console2.log("Future ID: %d", _futureId);
        console2.log("Deliverable: %s", _deliverable);
        console2.log("Deliverable Quantity: %d", _deliverableQuantity);
        console2.log("Total Supply: %d", _totalSupply);
        console2.log("Pay Token: %s", _payToken);
        console2.log("Price: %d", _price);
        console2.log("Security Deposit: %d", _securityDeposit);
        console2.log("Start Time: %d", _startTime);
        console2.log("Start Delivery Time: %d", _startDeliveryTime);
        console2.log("End Time: %d", _endTime);
        console2.log("Owner: %s", _owner);
        console2.log("Fee Rate: %d", _feeRate);
        
        (uint256 _totalDelivered,
            uint256 _totalClaimed,
            bool _hasDeposit,
            uint256 _mintedCount) = factory.futureStates(1);
        
        console2.log("Total Delivered: %d", _totalDelivered);
        console2.log("Total Claimed: %d", _totalClaimed);
        console2.log("Has Deposit: %s", _hasDeposit);
        console2.log("Minted Count: %d", _mintedCount);

        assertEq(_feeRate, 1);
    }

    function testFutureDeposit() public {
        uint256 beforeUsdt = usdt.balanceOf(address(this));
        factory.createFuture(address(deliverable), 1000 * 10**deliverable.decimals(), 100, address(usdt), 
            99 * 10**usdt.decimals(), 9990 * 10**usdt.decimals(),
            block.timestamp + 1 seconds, 
            block.timestamp + 1 hours,
            block.timestamp + 2 hours,
            owner);
        // approve to factory
        usdt.approve(address(factory), 10000 * 10**usdt.decimals());
        factory.deposit{value: 1 wei}(1);
        (uint256 _totalDelivered,
            uint256 _totalClaimed,
            bool _hasDeposit,
            uint256 _mintedCount) = factory.futureStates(1);
        assertEq(_totalDelivered, 0);
        assertEq(_totalClaimed, 0);
        assertTrue(_hasDeposit);
        assertEq(_mintedCount, 0);

        uint256 usdtBalance = usdt.balanceOf(address(this));
        assertEq(usdtBalance, beforeUsdt - 9990 * 10**usdt.decimals());
        uint256 usdtBalanceInFactory = usdt.balanceOf(address(factory));
        assertEq(usdtBalanceInFactory, 9990 * 10**usdt.decimals());
        console2.log("USDT Balance in this: %d", usdtBalance);
        console2.log("USDT Balance in Factory: %d", usdtBalanceInFactory);
        console2.log("ETH Balance in Factory: %d", address(factory).balance);

        // deposit again, failed
        vm.expectRevert();
        factory.deposit(1);
    }

    function testMintFuture() public {
        factory.createFuture(address(deliverable), 1000 * 10**deliverable.decimals(), 100, address(usdt), 
            99 * 10**usdt.decimals(), 9990 * 10**usdt.decimals(),
            block.timestamp + 1 seconds, 
            block.timestamp + 1 hours,
            block.timestamp + 2 hours,
            owner);
        // approve to factory
        usdt.approve(address(factory), 10000 * 10**usdt.decimals());
        factory.deposit(1);

        // mint
        vm.startPrank(user1);
        vm.warp(block.timestamp + 1 minutes);
        usdt.approve(address(factory), 10000 * 10**usdt.decimals());
        factory.mint(1, 1);
        uint256 user1NftCount = factory.balanceOf(user1, 1);
        assertEq(user1NftCount, 1);
        uint256 usdtBalance = usdt.balanceOf(address(user1));
        assertEq(usdtBalance, 10000 * 10**usdt.decimals() - 99 * 10**usdt.decimals());
        vm.stopPrank();

        uint256 usdtBalanceInFactory = usdt.balanceOf(address(factory));
        assertEq(usdtBalanceInFactory, 99 * 10**usdt.decimals() + 9990 * 10**usdt.decimals());
    }

    function testDeliver() public {
        factory.createFuture(address(deliverable), 1000 * 10**deliverable.decimals(), 100, address(usdt), 
            99 * 10**usdt.decimals(), 9990 * 10**usdt.decimals(),
            block.timestamp + 1 seconds, 
            block.timestamp + 1 hours,
            block.timestamp + 2 hours,
            owner);
        // approve to factory
        usdt.approve(address(factory), 10000 * 10**usdt.decimals());
        factory.deposit(1);

        // mint
        vm.startPrank(user1);
        vm.warp(block.timestamp + 1 minutes);
        usdt.approve(address(factory), 10000 * 10**usdt.decimals());
        factory.mint(1, 1);
        vm.stopPrank();

        // deliver
        vm.startPrank(owner);
        vm.warp(block.timestamp + 1 hours);
        deliverable.approve(address(factory), 10000 * 10**deliverable.decimals());
        factory.deliver(1, 10000 * 10**deliverable.decimals());
        vm.stopPrank();

        (uint256 _totalDelivered,
            uint256 _totalClaimed,
            bool _hasDeposit,
            uint256 _mintedCount) = factory.futureStates(1);
        assertEq(_totalDelivered, 10000 * 10**deliverable.decimals());
        assertEq(_totalClaimed, 0);
        assertTrue(_hasDeposit);
        assertEq(_mintedCount, 1);
    }

    function testDeliverClaim() public {
        factory.createFuture(address(deliverable), 1000 * 10**deliverable.decimals(), 100, address(usdt), 
            99 * 10**usdt.decimals(), 9990 * 10**usdt.decimals(),
            block.timestamp + 1 seconds, 
            block.timestamp + 1 hours,
            block.timestamp + 2 hours,
            owner);
        // approve to factory
        usdt.approve(address(factory), 10000 * 10**usdt.decimals());
        factory.deposit(1);

        // mint
        vm.startPrank(user1);
        vm.warp(block.timestamp + 1 minutes);
        usdt.approve(address(factory), 10000 * 10**usdt.decimals());
        factory.mint(1, 1);
        vm.stopPrank();

        // deliver
        vm.startPrank(owner);
        vm.warp(block.timestamp + 1 hours);
        deliverable.approve(address(factory), 10000 * 10**deliverable.decimals());
        factory.deliver(1, 10000 * 10**deliverable.decimals());
        
        // deliver claim
        uint256 beforeUsdt = usdt.balanceOf(address(owner));
        uint256 beforeUsdtFactory = usdt.balanceOf(address(factory));
        factory.deliverClaim(1);
        (,,,,,,,,,,,uint256 _feeRate) = factory.futureMetas(1);
        (uint256 _totalDelivered,
            uint256 _totalClaimed,
            bool _hasDeposit,
            uint256 _mintedCount) = factory.futureStates(1);
        assertEq(_totalDelivered, 10000 * 10**deliverable.decimals());
        assertEq(_totalClaimed, 99 * 10**usdt.decimals());
        assertTrue(_hasDeposit);
        assertEq(_mintedCount, 1);
        uint256 afterUsdt = usdt.balanceOf(address(owner));
        uint256 afterUsdtFactory = usdt.balanceOf(address(factory));
        uint256 realClaimed = 99 * 10**deliverable.decimals() * (100 - _feeRate) / 100;
        assertEq(afterUsdt, beforeUsdt + realClaimed);
        assertEq(afterUsdtFactory, beforeUsdtFactory - 99 * 10**deliverable.decimals());
        uint256 receiveFee = usdt.balanceOf(fundCollector);
        assertEq(receiveFee, 99 * 10**deliverable.decimals() - realClaimed);
        vm.stopPrank();
    }

    function testClaim() public {
        factory.createFuture(address(deliverable), 1000 * 10**deliverable.decimals(), 100, address(usdt), 
            99 * 10**usdt.decimals(), 9990 * 10**usdt.decimals(),
            block.timestamp + 1 seconds, 
            block.timestamp + 1 hours,
            block.timestamp + 2 hours,
            owner);
        // approve to factory
        usdt.approve(address(factory), 10000 * 10**usdt.decimals());
        factory.deposit(1);

        // mint
        vm.startPrank(user1);
        vm.warp(block.timestamp + 1 minutes);
        usdt.approve(address(factory), 10000 * 10**usdt.decimals());
        factory.mint(1, 1);
        vm.stopPrank();

        // deliver
        vm.startPrank(owner);
        vm.warp(block.timestamp + 1 hours);
        deliverable.approve(address(factory), 10000 * 10**deliverable.decimals());
        factory.deliver(1, 10000 * 10**deliverable.decimals());
        
        // deliver claim
        factory.deliverClaim(1);

        // claim
        vm.startPrank(user1);
        vm.warp(block.timestamp + 3 hours);
        factory.claim(1, 1);
        uint256 user1NftCount = factory.balanceOf(user1, 1);
        assertEq(user1NftCount, 0);
        uint256 user1DeliverableBalance = deliverable.balanceOf(user1);
        assertEq(user1DeliverableBalance, 1000 * 10**deliverable.decimals());
        vm.stopPrank();
    }

    function testRefund() public {
        factory.createFuture(address(deliverable), 1000 * 10**deliverable.decimals(), 100, address(usdt), 
            99 * 10**usdt.decimals(), 9990 * 10**usdt.decimals(),
            block.timestamp + 1 seconds, 
            block.timestamp + 1 hours,
            block.timestamp + 2 hours,
            owner);
        // approve to factory
        usdt.approve(address(factory), 10000 * 10**usdt.decimals());
        factory.deposit(1);

        // mint
        vm.startPrank(user1);
        vm.warp(block.timestamp + 1 minutes);
        usdt.approve(address(factory), 10000 * 10**usdt.decimals());
        factory.mint(1, 1);
        vm.stopPrank();

        // deliver
        vm.warp(block.timestamp + 1 hours);
        deliverable.approve(address(factory), 10000 * 10**deliverable.decimals());
        factory.deliver(1, 10000 * 10**deliverable.decimals());

        // refund
        uint256 beforeUsdt = usdt.balanceOf(address(this));
        vm.warp(block.timestamp + 3 hours);
        factory.refund(1);
        uint256 afterUsdt = usdt.balanceOf(address(this));
        assertEq(afterUsdt, beforeUsdt + 9990 * 10**usdt.decimals());
    }
}