// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../../src/subscriptions/Initiator.sol";

contract InitiatorTest is Test {
Initiator initiator;

function setUp() public {
    initiator = new Initiator();
}

// Fuzz test for `registerSubscription`
function testRegisterSubscriptionFuzz(
    address _subscriber,
    uint256 _amount,
    uint256 _validUntil,
    uint256 _paymentInterval,
    address _erc20Token
) public {
    vm.assume(_amount > 0 && _paymentInterval > 0);
    vm.prank(_subscriber);

    initiator.registerSubscription(_subscriber, _amount, _validUntil, _paymentInterval, _erc20Token);

    // Add assertions here
}

// Fuzz test for `removeSubscription`
function testRemoveSubscriptionFuzz(address _subscriber) public {
    // Setup a subscription before testing removal
    vm.prank(_subscriber);
    initiator.registerSubscription(_subscriber, 1, block.timestamp + 1 days, 1 days, address(0));

    vm.prank(_subscriber);
    initiator.removeSubscription(_subscriber);

    // Add assertions here
}

// Fuzz test for `initiatePayment`
function testInitiatePaymentFuzz(address _subscriber) public {
    // Setup a subscription before testing payment
    vm.prank(_subscriber);
    initiator.registerSubscription(_subscriber, 1, block.timestamp + 1 days, 1 days, address(0));

    vm.prank(_subscriber);
    initiator.initiatePayment(_subscriber);

    // Add assertions here
}

}