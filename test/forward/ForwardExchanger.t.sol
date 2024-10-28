// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {ForwardExchanger} from "../../src/forward/ForwardExchanger.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockToken is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {
        _mint(msg.sender, 1000000 * 10**decimals());
    }
}

contract ForwardExchangerTest is Test {
    address public owner;
    ForwardExchanger public exchanger;
    MockToken public deliveryToken;
    MockToken public paymentToken;
    address public consignee;
    address public shipper;

    function setUp() public {
        owner = address(this);
        consignee = address(0x1);
        shipper = address(0x2);

        deliveryToken = new MockToken("Mock Delivery Token", "mDT");
        paymentToken = new MockToken("Mock Payment Token", "mPT");

        deliveryToken.transfer(shipper, 10000 * 10**deliveryToken.decimals());
        paymentToken.transfer(consignee, 10000 * 10**paymentToken.decimals());
        vm.deal(consignee, 1000 ether);
    }

    function testExchangeWithERC20() public {
        // create a new exchanger
        uint256 deliveryAmount = 1000 * 10**deliveryToken.decimals();
        uint256 paymentAmount = 1000 * 10**paymentToken.decimals();
        uint256 expiredAt = block.timestamp + 1 hours;

        exchanger = new ForwardExchanger(address(deliveryToken), deliveryAmount, address(paymentToken), paymentAmount, expiredAt, consignee, shipper);

        assertEq(exchanger.deliveryToken(), address(deliveryToken));
        assertEq(exchanger.deliveryAmount(), deliveryAmount);
        assertEq(exchanger.paymentToken(), address(paymentToken));
        assertEq(exchanger.paymentAmount(), paymentAmount);
        assertEq(exchanger.expiredAt(), expiredAt);
        assertEq(exchanger.consignee(), consignee);
        assertEq(exchanger.shipper(), shipper);

        // pay the payment token
        vm.startPrank(consignee);
        paymentToken.approve(address(exchanger), paymentAmount);
        exchanger.pay();
        assertEq(paymentToken.balanceOf(address(exchanger)), paymentAmount);
        assertEq(exchanger.isPaid(), true);
        vm.stopPrank();

        // deliver the delivery token
        vm.startPrank(shipper);
        deliveryToken.approve(address(exchanger), deliveryAmount);
        exchanger.deliver();
        assertEq(deliveryToken.balanceOf(address(exchanger)), deliveryAmount);
        assertEq(exchanger.isDelivered(), true);
        vm.stopPrank();

        // exchange the tokens
        vm.startPrank(consignee);
        exchanger.exchange();
        assertEq(deliveryToken.balanceOf(consignee), deliveryAmount);
        assertEq(paymentToken.balanceOf(shipper), paymentAmount);
        assertEq(exchanger.isExchanged(), true);
        vm.stopPrank();

        // check the balance of the exchanger
        assertEq(deliveryToken.balanceOf(address(exchanger)), 0);
        assertEq(paymentToken.balanceOf(address(exchanger)), 0);

        // refund the tokens
        vm.warp(block.timestamp + 61 minutes);
        vm.startPrank(consignee);
        // failed
        vm.expectRevert(abi.encodeWithSelector(ForwardExchanger.RefundFailed.selector));
        exchanger.refund();
    }

    function testExchangeWithETH() public {
        // create a new exchanger
        uint256 deliveryAmount = 1000 * 10**deliveryToken.decimals();
        uint256 paymentAmount = 1000 * 10**paymentToken.decimals();
        uint256 expiredAt = block.timestamp + 1 hours;

        exchanger = new ForwardExchanger(address(deliveryToken), deliveryAmount, address(0), paymentAmount, expiredAt, consignee, shipper);

        assertEq(exchanger.deliveryToken(), address(deliveryToken));
        assertEq(exchanger.deliveryAmount(), deliveryAmount);
        assertEq(exchanger.paymentToken(), address(0));
        assertEq(exchanger.paymentAmount(), paymentAmount);
        assertEq(exchanger.expiredAt(), expiredAt);
        assertEq(exchanger.consignee(), consignee);
        assertEq(exchanger.shipper(), shipper);

        // pay the payment token
        vm.startPrank(consignee);
        exchanger.pay{value: paymentAmount}();
        assertEq(address(exchanger).balance, paymentAmount);
        assertEq(exchanger.isPaid(), true);
        vm.stopPrank();

        // deliver the delivery token
        vm.startPrank(shipper);
        deliveryToken.approve(address(exchanger), deliveryAmount);
        exchanger.deliver();
        assertEq(deliveryToken.balanceOf(address(exchanger)), deliveryAmount);
        assertEq(exchanger.isDelivered(), true);
        vm.stopPrank();

        // exchange the tokens
        vm.startPrank(consignee);
        exchanger.exchange();
        assertEq(deliveryToken.balanceOf(consignee), deliveryAmount);
        assertEq(address(exchanger).balance, 0);
        assertEq(exchanger.isExchanged(), true);
        vm.stopPrank();

        // check the balance of the exchanger
        assertEq(deliveryToken.balanceOf(address(exchanger)), 0);

        // refund the tokens
        vm.warp(block.timestamp + 61 minutes);
        vm.startPrank(consignee);
        // failed
        vm.expectRevert(abi.encodeWithSelector(ForwardExchanger.RefundFailed.selector));
        exchanger.refund();
    }

    function testRefundSuccess() public {
        // create a new exchanger
        uint256 deliveryAmount = 1000 * 10**deliveryToken.decimals();
        uint256 paymentAmount = 1000 * 10**paymentToken.decimals();
        uint256 expiredAt = block.timestamp + 1 hours;

        exchanger = new ForwardExchanger(address(deliveryToken), deliveryAmount, address(paymentToken), paymentAmount, expiredAt, consignee, shipper);

        // pay the payment token
        vm.startPrank(consignee);
        paymentToken.approve(address(exchanger), paymentAmount);
        exchanger.pay();
        assertEq(paymentToken.balanceOf(address(exchanger)), paymentAmount);
        assertEq(exchanger.isPaid(), true);
        vm.stopPrank();

        // deliver the delivery token
        vm.startPrank(shipper);
        deliveryToken.approve(address(exchanger), deliveryAmount);
        exchanger.deliver();
        assertEq(deliveryToken.balanceOf(address(exchanger)), deliveryAmount);
        assertEq(exchanger.isDelivered(), true);
        vm.stopPrank();

        console2.log("consignee balance", paymentToken.balanceOf(consignee));
        console2.log("shipper balance", deliveryToken.balanceOf(shipper));

        // refund the tokens
        vm.warp(block.timestamp + 61 minutes);
        vm.startPrank(consignee);
        // success
        exchanger.refund();
        assertEq(exchanger.isExchanged(), false);
        assertEq(exchanger.isPaid(), false);
        vm.stopPrank();

        // check tokens after refund
        assertEq(deliveryToken.balanceOf(address(exchanger)), 0);
        assertEq(paymentToken.balanceOf(address(exchanger)), 0);
        // print the balance of the exchanger
        console2.log("consignee balance: %d", paymentToken.balanceOf(consignee));
        console2.log("shipper balance: %d", deliveryToken.balanceOf(shipper));
    }

}