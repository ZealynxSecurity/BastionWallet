// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../../src/subscriptions/Initiator.sol";

contract InitiatorInvariantTest is Test {
Initiator initiator;

function setUp() public {
    initiator = new Initiator();
}

// Invariant to ensure the integrity of each subscription
function invariant_SubscriptionValidity() public {
    address[] memory subscribers = initiator.getSubscribers();
    for (uint i = 0; i < subscribers.length; i++) {
        ISubExecutor.SubStorage memory sub = initiator.getSubscription(subscribers[i]);
        if (sub.amount > 0) {
            assert(sub.validUntil > block.timestamp || block.timestamp < sub.validAfter);
            assert(sub.paymentInterval > 0);
        }
    }
}

// Invariant to ensure the subscriber list is accurate
function invariant_SubscriberList() public {
    address[] memory subscribers = initiator.getSubscribers();
    for (uint i = 0; i < subscribers.length; i++) {
        ISubExecutor.SubStorage memory sub = initiator.getSubscription(subscribers[i]);
        assert(sub.amount > 0);
    }
}

// Invariant to check the contract's ETH balance
uint lastKnownEthBalance;

function setUp_PostInvariantCheck() public {
    lastKnownEthBalance = address(initiator).balance;
}

function invariant_EthBalance() public {
    uint balance = address(initiator).balance;
    assert(balance >= lastKnownEthBalance);
}

}