// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {MiningPassFactory} from "../src/MiningPassFactory.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockUSDT is ERC20 {
    constructor() ERC20("Mock USDT", "mUSDT") {
        _mint(msg.sender, 1000000 * 10**decimals());
    }
}

contract MiningShareFactoryTest is Test {
    uint256 public constant ROUND_ID_SHIFT = 128;

    MiningPassFactory public factory;
    MockUSDT public usdt;
    address public owner;
    address public user1;
    address public user2;
    address public fundCollector;

    function setUp() public {
        owner = address(this);
        user1 = address(0x1);
        user2 = address(0x2);
        fundCollector = address(0x3);

        usdt = new MockUSDT();
        factory = new MiningPassFactory(address(usdt), fundCollector, "https://example.com/metadata/");

        // Transfer some USDT to users for testing
        usdt.transfer(user1, 10000 * 10**usdt.decimals());
        usdt.transfer(user2, 10000 * 10**usdt.decimals());
    }

    function testCreateRound() public {
        uint256 totalShares = 100;
        uint256 pricePerShare = 100 * 10**usdt.decimals(); // 100 USDT
        uint256 startTime = block.timestamp + 1 hours;
        uint256 endTime = startTime + 1 days;
        uint256 whitelistEndTime = startTime + 12 hours;
        uint256 miningDays = 30;

        factory.createRound(0, totalShares, pricePerShare, startTime, endTime, whitelistEndTime, miningDays);

        (uint256 _roundType, uint256 _totalShares, uint256 _pricePerShare, uint256 _startTime, uint256 _endTime, uint256 _whitelistEndTime, uint256 _mintedCount, uint256 _miningDays) = factory.rounds(1);

        assertEq(_roundType, 0);
        assertEq(_totalShares, totalShares);
        assertEq(_pricePerShare, pricePerShare);
        assertEq(_startTime, startTime);
        assertEq(_endTime, endTime);
        assertEq(_whitelistEndTime, whitelistEndTime);
        assertEq(_mintedCount, 0);
        assertEq(_miningDays, miningDays);
    }

    function testSetWhitelist() public {
        address[] memory whitelistedAddresses = new address[](2);
        whitelistedAddresses[0] = user1;
        whitelistedAddresses[1] = user2;

        factory.createRound(0, 100, 100 * 10**usdt.decimals(), block.timestamp, block.timestamp + 1 days, block.timestamp + 12 hours, 30);
        factory.setWhitelist(1, whitelistedAddresses);

//        assertTrue(factory.rounds(1).whitelist[user1]);
//        assertTrue(factory.rounds(1).whitelist[user2]);
//        assertFalse()(factory.rounds().whitelist[address(0x4)]);

        // Test minting behavior
        vm.warp(block.timestamp + 1 hours); // Move to whitelist period

        vm.startPrank(user1);
        usdt.approve(address(factory), 100 * 10**usdt.decimals());
        factory.mint(1, 1); // This should succeed for user1
        vm.stopPrank();

        vm.startPrank(user2);
        usdt.approve(address(factory), 100 * 10**usdt.decimals());
        factory.mint(1, 1); // This should succeed for user2
        vm.stopPrank();

        vm.expectRevert(); // This should fail for non-whitelisted address
        vm.prank(address(0x4));
        factory.mint(1, 1);
    }

    function testMint() public {
        uint256 pricePerShare = 100 * 10**usdt.decimals(); // 100 USDT
        factory.createRound(0, 100, pricePerShare, block.timestamp, block.timestamp + 1 days, block.timestamp + 12 hours, 30);

        vm.warp(block.timestamp + 13 hours); // Move to whitelist period

        vm.startPrank(user1);
        usdt.approve(address(factory), pricePerShare);
        factory.mint(1, 1);
        vm.stopPrank();

        assertEq(factory.balanceOf(user1, 1), 1);
        assertEq(usdt.balanceOf(fundCollector), pricePerShare);
    }

    function testBatchMint() public {
        uint256 pricePerShare = 100 * 10**usdt.decimals(); // 100 USDT
        uint256 quantity = 5;
        factory.createRound(0, 100, pricePerShare, block.timestamp, block.timestamp + 1 days, block.timestamp + 12 hours, 30);

        vm.warp(block.timestamp + 13 hours); // Move to whitelist period

        vm.startPrank(user1);
        usdt.approve(address(factory), pricePerShare * quantity);
        factory.mint(1, quantity);
        vm.stopPrank();

        assertEq(factory.balanceOf(user1, 1), quantity);
        assertEq(usdt.balanceOf(fundCollector), pricePerShare * quantity);
    }

    function testFailMintBeforeStart() public {
        uint256 pricePerShare = 100 * 10**usdt.decimals(); // 100 USDT
        factory.createRound(0, 100, pricePerShare, block.timestamp, block.timestamp + 1 days, block.timestamp + 2 hours, 30);

        vm.startPrank(user1);
        usdt.approve(address(factory), pricePerShare);
        factory.mint(1, 1);
        vm.stopPrank();
    }

    function testFailMintAfterEnd() public {
        uint256 pricePerShare = 100 * 10**usdt.decimals(); // 100 USDT
        factory.createRound(0, 100, 100 * 10**usdt.decimals(), block.timestamp, block.timestamp + 1 hours, block.timestamp + 30 minutes, 30);

        vm.warp(block.timestamp + 2 hours);
        usdt.approve(address(factory), pricePerShare);
        vm.prank(user1);
        factory.mint(1, 1);
    }

    function testFailMintWhenNotWhitelisted() public {
        uint256 pricePerShare = 100 * 10**usdt.decimals(); // 100 USDT
        factory.createRound(0, 100, 100 * 10**usdt.decimals(), block.timestamp, block.timestamp + 1 days, block.timestamp + 12 hours, 30);

        address[] memory whitelistedAddresses = new address[](1);
        whitelistedAddresses[0] = user2;
        factory.setWhitelist(1, whitelistedAddresses);

        vm.prank(user1);
        usdt.approve(address(factory), pricePerShare);
        factory.mint(1, 1);
    }

    function testFailMintWhenAllSharesMinted() public {
        uint256 totalShares = 2;
        uint256 pricePerShare = 100 * 10**usdt.decimals();
        factory.createRound(0, totalShares, pricePerShare, block.timestamp, block.timestamp + 1 days, block.timestamp + 12 hours, 30);

        vm.startPrank(user1);
        usdt.approve(address(factory), pricePerShare * (totalShares + 1));
        factory.mint(1, 1);
        factory.mint(1, 1);
        factory.mint(1, 1); // This should fail
        vm.stopPrank();
    }

    function testFailBatchMintWithZeroQuantity() public {
        factory.createRound(0, 100, 100 * 10**usdt.decimals(), block.timestamp, block.timestamp + 1 days, block.timestamp + 12 hours, 30);

        vm.prank(user1);
        factory.mint(1, 0);
    }

//    function testGetRoundIdFromShareId() public {
//        factory.createRound(100, 100 * 10**usdt.decimals(), block.timestamp, block.timestamp + 1 days, block.timestamp + 12 hours, 30);
//        factory.createRound(200, 100 * 10**usdt.decimals(), block.timestamp, block.timestamp + 1 days, block.timestamp + 12 hours, 30);
//
//        assertEq(factory.getRoundIdFromShareId(0), 1);
//        assertEq(factory.getRoundIdFromShareId(99), 1);
//        assertEq(factory.getRoundIdFromShareId(100), 2);
//        assertEq(factory.getRoundIdFromShareId(299), 2);
//    }

//    function testFailGetRoundIdFromInvalidShareId() public view {
//        factory.getRoundIdFromShareId(300); // This should fail as we only have 300 shares in total
//    }

    function testTokenURI() public {
        factory.createRound(0, 100, 100 * 10**usdt.decimals(), block.timestamp, block.timestamp + 1 days, block.timestamp + 12 hours, 30);

        vm.warp(block.timestamp + 13 hours);
        vm.startPrank(user1);
        usdt.approve(address(factory), 100 * 10**usdt.decimals());
        factory.mint(1, 1);
        vm.stopPrank();

        assertEq(factory.uri(1), "https://example.com/metadata/1");
    }
}
