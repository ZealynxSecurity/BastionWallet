// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../subscriptions/Initiator.sol";
import "../MockERC20.sol";
import "./EchidnaConfig.sol";

contract EchidnaInitiator is EchidnaConfig {
    Initiator public initiator;
    MockERC20 public token;
    address internal _erc20Token;

    address constant _subscriber = USER1;

    constructor() {
        initiator = new Initiator();
        token = new MockERC20("Test Token", "TT");

        _erc20Token = address(token);

    }

    // Tests various inputs for registering a subscription
    function test_subscription_registration(
        uint256 _amount, 
        uint256 _validUntil, 
        uint256 _paymentInterval
    ) public {
        // Assumptions to ensure valid inputs
        require(_amount == 0 || _paymentInterval == 0);
        require(_validUntil > block.timestamp);

        initiator.registerSubscription(_subscriber, _amount, _validUntil, _paymentInterval, _erc20Token);
        ISubExecutor.SubStorage memory sub = initiator.getSubscription(_subscriber);

        assert(sub.amount == _amount && sub.paymentInterval == _paymentInterval);
    }

    // Test that a subscription can be successfully removed.
    function test_remove_subscription(
        uint256 _amount, 
        uint256 _validUntil, 
        uint256 _paymentInterval
    ) public {
        // Test for subscription registration
        require(_validUntil > block.timestamp);
        

        initiator.registerSubscription(_subscriber, _amount, _validUntil, _paymentInterval, _erc20Token);
        initiator.removeSubscription(_subscriber);
        ISubExecutor.SubStorage memory sub = initiator.getSubscription(_subscriber);

        // Checking if the subscription is effectively removed
        assert(sub.amount == 0);
    }

    // Test that only the subscriber can register a subscription
    function test_only_subscriber_can_register(
        uint256 _amount, 
        uint256 _paymentInterval,
        uint256 _validUntil
    ) public {
        require(_amount == 0 || _paymentInterval == 0);
        require(_validUntil > block.timestamp);

        
        // Simulate a different address trying to register the subscription
        hevm.prank(USER2);
        try initiator.registerSubscription(_subscriber, _amount, _validUntil, _paymentInterval, _erc20Token) {
            // If this line is reached, the test should fail
            assert(false);
        } catch {
            // Expected behavior, the transaction should revert
        }
        
        // Now the actual subscriber tries to register the subscription
        hevm.prank(_subscriber);
        initiator.registerSubscription(_subscriber, _amount, _validUntil, _paymentInterval, _erc20Token);
        
        ISubExecutor.SubStorage memory sub = initiator.getSubscription(_subscriber);
        assert(sub.amount == _amount);
        assert(sub.paymentInterval == _paymentInterval);
    }

    // Test that only the subscriber can remove a subscription
    function test_only_subscriber_can_remove(
        uint256 _amount, 
        uint256 _paymentInterval,
        uint256 _validUntil
    ) public {
        require(_amount == 0 || _paymentInterval == 0);
        require(_validUntil > block.timestamp);

        // Registering a subscription first
        hevm.prank(_subscriber);
        initiator.registerSubscription(_subscriber, _amount, _validUntil, _paymentInterval, _erc20Token);
        
        // Simulate a different address trying to remove the subscription
        hevm.prank(USER2);
        try initiator.removeSubscription(_subscriber) {
            // If this line is reached, the test should fail
            assert(false);
        } catch {
            // Expected behavior, the transaction should revert
        }

        // Now the actual subscriber tries to remove the subscription
        hevm.prank(_subscriber);
        initiator.removeSubscription(_subscriber);
        ISubExecutor.SubStorage memory sub = initiator.getSubscription(_subscriber);
        assert(sub.amount == 0);
    }


}