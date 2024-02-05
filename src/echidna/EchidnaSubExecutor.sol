// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../../src/subscriptions/Initiator.sol";
import "../subscriptions/SubExecutor.sol";
import "../MockERC20.sol";
import "./EchidnaConfig.sol";

contract EchidnaSubExecutor is EchidnaConfig {
    Initiator initiator;
    SubExecutor public subExecutor;
    MockERC20 public token;
    address public _erc20Token;

    constructor() {
        subExecutor = new SubExecutor();
        initiator = new Initiator();
        token = new MockERC20("Test Token", "TT");

        _erc20Token = address(token);
    }

    // Function to setup the payment history
    function setupPaymentHistory(
        uint256 amount, 
        uint256 numPayments, 
        uint256 paymentInterval, 
        uint256 validUntil, 
        address erc20Token
    ) internal {
        if(amount == 0 || paymentInterval == 0) return;

        // Register a new subscription
        hevm.prank(subExecutor.getOwner());
        subExecutor.createSubscription(address(initiator), amount, paymentInterval, validUntil, erc20Token);

        // Simulate payments
        for (uint256 i = 0; i < numPayments; i++) {
            // Warp time and set up balances to make payments possible
            hevm.warp(block.timestamp + paymentInterval);
            hevm.deal(address(subExecutor), amount);
            subExecutor.processPayment();
        }
    }

    // Echidna test to ensure createSubscription respects access control
    function test_create_subscription_access_control(
        uint256 _amount, 
        uint256 _paymentInterval,
        uint256 _validUntil
    ) public {
        if(_amount == 0 || _paymentInterval == 0) return;

        // Case 1: Caller is the owner itself (should succeed)
        hevm.prank(subExecutor.getOwner());
        try subExecutor.createSubscription(address(initiator), _amount, _paymentInterval, _validUntil, _erc20Token) {
            // Success is expected, no action needed
        } catch {
            // If this line is reached, the test should fail
            assert(false);
        }

        // Case 2: Caller is not EntryPoint, Owner, or Self (should fail)
        address unauthorizedCaller = address(0x1234);
        hevm.prank(unauthorizedCaller);
        (bool success,) = address(subExecutor).call(abi.encodeWithSelector(
            subExecutor.createSubscription.selector,
            address(initiator), _amount, _paymentInterval, _validUntil, _erc20Token
        ));

        // Expecting call to fail
        assert(!success);
    }

    // Echidna test to ensure modifySubscription respects access control
    function test_modify_subscription_access_control(
        uint256 _amount, 
        uint256 _paymentInterval,
        uint256 _validUntil
    ) public {
        if(_amount == 0 || _paymentInterval == 0) return;

        // Case 1: Caller is the owner itself (should succeed)
        hevm.prank(subExecutor.getOwner());
        try subExecutor.modifySubscription(address(initiator), _amount, _paymentInterval, _validUntil, _erc20Token) {
            // Success is expected, no action needed
        } catch {
            // If this line is reached, the test should fail
            assert(false);
        }

        // Case 2: Caller is not EntryPoint, Owner, or Self (should fail)
        address unauthorizedCaller = address(0x1234);
        (bool success,) = address(subExecutor).call(abi.encodeWithSelector(
            subExecutor.modifySubscription.selector,
            address(initiator), _amount, _paymentInterval, _validUntil, _erc20Token
        ));

        // Expecting call to fail
        assert(!success);
    }

    // Echidna test to ensure revokeSubscription respects access control
    function test_revoke_subscription_access_control() public {
        // Case 1: Caller is the owner itself (should succeed)
        hevm.prank(subExecutor.getOwner());
        try subExecutor.revokeSubscription(address(initiator)) {
            // Success is expected, no action needed
        } catch {
            // If this line is reached, the test should fail
            assert(false);
        }

        // Case 2: Caller is not EntryPoint, Owner, or Self (should fail)
        address unauthorizedCaller = address(0x1234);
        (bool success,) = address(subExecutor).call(abi.encodeWithSelector(
            subExecutor.revokeSubscription.selector,
            address(initiator)
        ));

        // Expecting call to fail
        assert(!success);
    }

    function test_subscription_validity(
        address subscriber, 
        uint256 amount, 
        uint256 numPayments, 
        uint256 paymentInterval, 
        uint256 validUntil
    ) public {
        setupPaymentHistory(
            amount, 
            numPayments,
            paymentInterval,
            validUntil,
            _erc20Token
        );
        address[] memory allSubscribers = new address[](3);
        allSubscribers[0] = USER1;
        allSubscribers[1] = USER2;
        allSubscribers[2] = USER3;

        for (uint i = 0; i < allSubscribers.length; i++) {
            SubStorage memory sub = subExecutor.getSubscription(allSubscribers[i]);
            PaymentRecord[] memory paymentHistory = subExecutor.getPaymentHistory(allSubscribers[i]);

            if (paymentHistory.length > 0) {
                // Ensure that the time since the last payment exceeds the payment interval
                PaymentRecord memory lastPayment = paymentHistory[paymentHistory.length - 1];
                assert(block.timestamp < lastPayment.timestamp + sub.paymentInterval || block.timestamp > sub.validUntil);
            } else {
                // If no payments have been made, ensure that the subscription is still in its initial interval
                assert(block.timestamp < sub.validAfter + sub.paymentInterval || block.timestamp > sub.validUntil);
            }
        }
    }

}