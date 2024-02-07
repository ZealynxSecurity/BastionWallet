// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../../src/subscriptions/Initiator.sol";
import "../subscriptions/SubExecutor.sol";
import "./EchidnaSetup.sol";
import "./Debugger.sol";

contract EchidnaSubExecutor is EchidnaSetup {
    Initiator initiator;
    SubExecutor public subExecutor;
    address immutable public entryPoint;
    address[] public allSubscribers;

    constructor() {
        subExecutor = new SubExecutor();
        initiator = new Initiator();

        entryPoint = 0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789;

        allSubscribers = new address[](3);
        allSubscribers[0] = USER1;
        allSubscribers[1] = USER2;
        allSubscribers[2] = USER3;
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

        // Case 2: Caller is the Entrypoint (should succeed)
        hevm.prank(address(entryPoint));
        try subExecutor.createSubscription(address(initiator), _amount, _paymentInterval, _validUntil, _erc20Token) {
            // Success is expected, no action needed
        } catch {
            // If this line is reached, the test should fail
            assert(false);
        }

        // Case 3: Caller is not EntryPoint, Owner, or Self (should fail)
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

        // Case 2: Caller is the Entrypoint (should succeed)
        hevm.prank(address(entryPoint));
        try subExecutor.modifySubscription(address(initiator), _amount, _paymentInterval, _validUntil, _erc20Token) {
            // Success is expected, no action needed
        } catch {
            // If this line is reached, the test should fail
            assert(false);
        }

        // Case 3: Caller is not EntryPoint, Owner, or Self (should fail)
        address unauthorizedCaller = address(0x1234);
        (bool success,) = address(subExecutor).call(abi.encodeWithSelector(
            subExecutor.modifySubscription.selector,
            address(initiator), _amount, _paymentInterval, _validUntil, _erc20Token
        ));

        // We're expecting call function above to fail
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

        // Case 2: Caller is the EntryPoint (should succeed)
        hevm.prank(address(entryPoint));
        try subExecutor.revokeSubscription(address(initiator)) {
            // Success is expected, no action needed
        } catch {
            // If this line is reached, the test should fail
            assert(false);
        }

        // Case 3: Caller is not EntryPoint, Owner, or Self (should fail)
        address unauthorizedCaller = address(0x1234);
        (bool success,) = address(subExecutor).call(abi.encodeWithSelector(
            subExecutor.revokeSubscription.selector,
            address(initiator)
        ));

        // Expecting call to fail
        assert(!success);
    }

    function test_subscription_validity_initial_interval() public {       
        for (uint i = 0; i < allSubscribers.length; i++) {
            SubStorage memory sub = subExecutor.getSubscription(allSubscribers[i]);
            PaymentRecord[] memory paymentHistory = subExecutor.getPaymentHistory(allSubscribers[i]);

            // If no payments have been made, ensure that the subscription is still in its initial interval
            // with paymentHistory.length = 0
            assert(block.timestamp < sub.validAfter + sub.paymentInterval || block.timestamp > sub.validUntil);
        }
    }

    // Echidna test to try to break the validity period in SubExecutor's processPayment function
    function test_payment_validity_period(uint256 _amount, uint256 _paymentInterval) public {
        if (_amount == 0 || _paymentInterval == 0) return;

        Debugger.log("timestamp numero! ", block.timestamp);

        uint256 _validAfter = block.timestamp + 1 days;
        uint256 _validUntil = _validAfter + 10 days;

        Debugger.log("_validAfter numero! ", _validAfter);
        Debugger.log("_validUntil numero! ", _validUntil);

        // Registering a subscription
        hevm.prank(address(entryPoint));
        subExecutor.createSubscription(
            address(initiator), 
            _amount, 
            _paymentInterval, 
            _validUntil, 
            _erc20Token
        );

        // Warp to a time before the subscription is valid
        hevm.warp(_validAfter - 10);
        Debugger.log("timestamp with _validAfter - 10! ", block.timestamp);

        hevm.prank(subExecutor.getOwner());
        try subExecutor.processPayment() {
            // If this line is reached, the test should fail
            assert(false);
        } catch {
            // Expected behavior, the transaction should revert
        }

        // Warp to a time after the subscription has expired
        hevm.warp(_validUntil + 10);
        Debugger.log("timestamp with _validUntil + 10! ", block.timestamp);

        hevm.prank(subExecutor.getOwner());
        try subExecutor.processPayment() {
            // If this line is reached, the test should fail
            assert(false);
        } catch {
            // Expected behavior, the transaction should revert
        }

        // Warp to a time within the valid range and ensure it doesn't revert
        hevm.warp(_validAfter + 1);
        hevm.prank(subExecutor.getOwner());
        try subExecutor.processPayment() {
            // Expected behavior, the transaction should succeed
        } catch {
            assert(false);
        }
    }
}