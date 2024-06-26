// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../subscriptions/Initiator.sol";
import "./EchidnaSetup.sol";
import "./Debugger.sol";

contract EchidnaInitiator is EchidnaSetup {
    Initiator internal initiator;
    address internal _subscriber;

    constructor() {
        initiator = new Initiator();
        _subscriber = msg.sender;
    }

    /////////////////////////////////////////////////////////////////////////
    // registerSubscription
    /////////////////////////////////////////////////////////////////////////

    function test_subscription_registration(
        uint256 _amount, 
        uint256 _validUntil, 
        uint256 _paymentInterval
    ) public {
        // Assumptions to ensure valid inputs
        if(_amount == 0 || _paymentInterval == 0) return;

        initiator.registerSubscription(_subscriber, _amount, _validUntil, _paymentInterval, _erc20Token);
        ISubExecutor.SubStorage memory sub = initiator.getSubscription(_subscriber);

        assert(sub.amount == _amount && sub.paymentInterval == _paymentInterval);
    }

    // Test that only the subscriber can register a subscription
    function test_only_subscriber_can_register(
        uint256 _amount, 
        uint256 _paymentInterval,
        uint256 _validUntil
    ) public {
        if(_amount == 0 || _paymentInterval == 0) return;
        
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

    // Test that registerSubscription reverts if _validUntil is smaller than block.timestamp
    function test_register_with_expired_subscription(uint256 _amount, uint256 _paymentInterval) public {
        if(_amount == 0 || _paymentInterval == 0) return;

        uint256 _validUntil = block.timestamp - 365 days; // Setting validUntil in the past

        hevm.prank(_subscriber);
        try initiator.registerSubscription(_subscriber, _amount, _validUntil, _paymentInterval, _erc20Token) {
            // If this line is reached, the test should fail
            assert(false);
        } catch {
            // Expected behavior, the transaction should revert
            assert(true);
        }
    }

    // Test user can register multiple times
    function test_subscription_multiple_registration() public {
        uint256 _amount = 1;
        uint256 _validUntil = 5;
        uint256 _paymentInterval = 1;
        uint256 repeat = 200;

        for (uint256 index; index < repeat; index++) {
            hevm.prank(_subscriber);
            Debugger.log("Gas Left: ", gasleft());
            initiator.registerSubscription(_subscriber, _amount, _validUntil, _paymentInterval, _erc20Token);
        }        
    }

    /////////////////////////////////////////////////////////////////////////
    // removeSubscription
    /////////////////////////////////////////////////////////////////////////

    // Test that a subscription can be successfully removed.
    function test_remove_subscription(
        uint256 _amount, 
        uint256 _validUntil, 
        uint256 _paymentInterval
    ) public {
        // Test for subscription registration
        if(_amount == 0 || _paymentInterval == 0) return;        

        initiator.registerSubscription(_subscriber, _amount, _validUntil, _paymentInterval, _erc20Token);
        initiator.removeSubscription(_subscriber);
        ISubExecutor.SubStorage memory sub = initiator.getSubscription(_subscriber);

        // Checking if the subscription is effectively removed
        assert(sub.amount == 0);
    }

    // Test that only the subscriber can remove a subscription
    function test_only_subscriber_can_remove(
        uint256 _amount, 
        uint256 _paymentInterval,
        uint256 _validUntil
    ) public {
        if(_amount == 0 || _paymentInterval == 0) return;

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

    /////////////////////////////////////////////////////////////////////////
    // initiatePayment
    /////////////////////////////////////////////////////////////////////////

    // Test that initiatePayment reverts if block.timestamp is outside the valid range
    function test_payment_validity_early_subscription(uint256 _amount, uint256 _paymentInterval) public {
        if(_amount == 0 || _paymentInterval == 0) return;

        uint256 _validAfter = block.timestamp + 1 days;
        uint256 _validUntil = _validAfter + 10 days;

        // Registering a subscription
        hevm.prank(_subscriber);
        initiator.registerSubscription(
            _subscriber, 
            _amount, 
            _validUntil, 
            _paymentInterval, 
            _erc20Token
        );

        // Warp to a time before the subscription is valid
        hevm.warp(_validAfter - 10);
        hevm.prank(_subscriber);
        try initiator.initiatePayment(_subscriber) {
            // If this line is reached, the test should fail
            assert(false);
        } catch {
            // Expected behavior, the transaction should revert
            assert(true);
        }
    }

    // Test that initiatePayment reverts if block.timestamp is outside the valid range
    function test_payment_validity_expired_subscription(uint256 _amount, uint256 _paymentInterval) public {
        if(_amount == 0 || _paymentInterval == 0) return;

        uint256 _validAfter = block.timestamp + 1 days;
        uint256 _validUntil = _validAfter + 10 days;

        // Registering a subscription
        hevm.prank(_subscriber);
        initiator.registerSubscription(
            _subscriber, 
            _amount, 
            _validUntil, 
            _paymentInterval, 
            _erc20Token
        );

        // Warp to a time after the subscription has expired
        hevm.warp(_validUntil + 10);
        hevm.prank(_subscriber);
        try initiator.initiatePayment(_subscriber) {
            // If this line is reached, the test should fail
            assert(false);
        } catch {
            // Expected behavior, the transaction should revert
            assert(true);
        }
    }

    // Test that initiatePayment reverts if block.timestamp is outside the valid range
    function test_payment_valid(uint256 _amount, uint256 _paymentInterval, uint256 _timePayment) public {
        uint256 _validUntil = block.timestamp + 10 days;

        if(_amount == 0 || _paymentInterval == 0) return;
        if(block.timestamp < _timePayment || _timePayment > _validUntil) return;

        // Registering a subscription
        hevm.prank(_subscriber);
        initiator.registerSubscription(
            _subscriber, 
            _amount, 
            _validUntil, 
            _paymentInterval, 
            _erc20Token
        );

        // Warp to a time within the valid range and ensure it doesn't revert
        hevm.prank(_subscriber);
        hevm.warp(_timePayment);
        try initiator.initiatePayment(_subscriber) {
            // Expected behavior, the transaction should succeed
            assert(true);
        } catch {
            assert(false);
        }
    }
}