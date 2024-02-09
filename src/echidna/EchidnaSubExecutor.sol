// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../../src/subscriptions/Initiator.sol";
import "../subscriptions/SubExecutor.sol";
import "./EchidnaSetup.sol";

contract EchidnaSubExecutor is EchidnaSetup {
    Initiator initiator;
    SubExecutor internal subExecutor;
    address immutable internal entryPoint;
    address[] internal allSubscribers;
    address internal deployer;

    constructor() {
        subExecutor = new SubExecutor();
        initiator = new Initiator();
        deployer = msg.sender;

        entryPoint = 0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789;

        allSubscribers = new address[](3);
        allSubscribers[0] = USER1;
        allSubscribers[1] = USER2;
        allSubscribers[2] = USER3;
    }

    /////////////////////////////////////////////////////////////////////////
    // createSubscription
    /////////////////////////////////////////////////////////////////////////

    // Echidna test to ensure createSubscription respects access control
    function test_create_subscription_access_control_owner(uint256 _amount, uint256 _paymentInterval, uint256 _validUntil ) public {
        if(_amount == 0 || _paymentInterval == 0) return;

        // Case 1: Caller is the owner itself (should succeed)
        hevm.prank(subExecutor.getOwner());
        try subExecutor.createSubscription(address(initiator), _amount, _paymentInterval, _validUntil, _erc20Token) {
            // Success is expected, no action needed
            assert(true);
        } catch {
            // If this line is reached, the test should fail
            assert(false);
        }
    }

    // Echidna test to ensure createSubscription respects access control
    function test_create_subscription_access_control_entrypoint(uint256 _amount, uint256 _paymentInterval, uint256 _validUntil ) public {
        if(_amount == 0 || _paymentInterval == 0) return;

        // Case 2: Caller is the Entrypoint (should succeed)
        hevm.prank(address(entryPoint));
        try subExecutor.createSubscription(address(initiator), _amount, _paymentInterval, _validUntil, _erc20Token) {
            // Success is expected, no action needed
            assert(true);
        } catch {
            // If this line is reached, the test should fail
            assert(false);
        }
    }

    // Echidna test to ensure createSubscription respects access control
    function test_create_subscription_access_control_unauthorized(uint256 _amount, uint256 _paymentInterval, uint256 _validUntil ) public {
        if(_amount == 0 || _paymentInterval == 0) return;

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

    /////////////////////////////////////////////////////////////////////////
    // modifySubscription
    /////////////////////////////////////////////////////////////////////////

    // Echidna test to ensure modifySubscription respects access control
    function test_modify_subscription_access_control_owner(uint256 _amount, uint256 _paymentInterval, uint256 _validUntil ) public {
        if(_amount == 0 || _paymentInterval == 0) return;

        // Case 1: Caller is the owner itself (should succeed)
        hevm.prank(subExecutor.getOwner());
        try subExecutor.modifySubscription(address(initiator), _amount, _paymentInterval, _validUntil, _erc20Token) {
            // Success is expected, no action needed
            assert(true);
        } catch {
            // If this line is reached, the test should fail
            assert(false);
        }
    }

    // Echidna test to ensure modifySubscription respects access control
    function test_modify_subscription_access_control_entrypoint(uint256 _amount, uint256 _paymentInterval, uint256 _validUntil ) public {
        if(_amount == 0 || _paymentInterval == 0) return;

        // Case 2: Caller is the Entrypoint (should succeed)
        hevm.prank(address(entryPoint));
        try subExecutor.modifySubscription(address(initiator), _amount, _paymentInterval, _validUntil, _erc20Token) {
            // Success is expected, no action needed
            assert(true);
        } catch {
            // If this line is reached, the test should fail
            assert(false);
        }
    }

    // Echidna test to ensure modifySubscription respects access control
    function test_modify_subscription_access_control_unauthorized(uint256 _amount, uint256 _paymentInterval, uint256 _validUntil ) public {
        if(_amount == 0 || _paymentInterval == 0) return;

        // Case 3: Caller is not EntryPoint, Owner, or Self (should fail)
        address unauthorizedCaller = address(0x1234);
        hevm.prank(unauthorizedCaller);
        (bool success,) = address(subExecutor).call(abi.encodeWithSelector(
            subExecutor.modifySubscription.selector,
            address(initiator), _amount, _paymentInterval, _validUntil, _erc20Token
        ));

        // We're expecting call function above to fail
        assert(!success);
    }

    /////////////////////////////////////////////////////////////////////////
    // remvokeSubscription
    /////////////////////////////////////////////////////////////////////////

    // Echidna test to ensure revokeSubscription respects access control
    function test_revoke_subscription_access_control_owner() public {
        uint256 _amount = 25;
        uint256 _paymentInterval = 2000;
        uint256 _validUntil = block.timestamp + 10 days;

        hevm.prank(subExecutor.getOwner());
        subExecutor.createSubscription(
            address(initiator), 
            _amount, 
            _paymentInterval, 
            _validUntil, 
            _erc20Token
        );

        // Case 1: Caller is the owner itself (should succeed)
        hevm.prank(subExecutor.getOwner());
        try subExecutor.revokeSubscription(address(initiator)) {
            // Success is expected, no action needed
            assert(true);
        } catch {
            // If this line is reached, the test should fail
            assert(false);
        }
    }

     // Echidna test to ensure revokeSubscription respects access control
    function test_revoke_subscription_access_control_entrypoint() public {
        uint256 _amount = 25;
        uint256 _paymentInterval = 2000;
        uint256 _validUntil = block.timestamp + 10 days;

        hevm.prank(address(entryPoint));
        subExecutor.createSubscription(
            address(initiator), 
            _amount, 
            _paymentInterval, 
            _validUntil, 
            _erc20Token
        );

        // Case 2: Caller is the EntryPoint (should succeed)
        hevm.prank(address(entryPoint));
        try subExecutor.revokeSubscription(address(initiator)) {
            // Success is expected, no action needed
            assert(true);
        } catch {
            // If this line is reached, the test should fail
            assert(false);
        }
    }

    // Echidna test to ensure revokeSubscription respects access control
    function test_revoke_subscription_access_control_unauthorized() public {
        uint256 _amount = 25;
        uint256 _paymentInterval = 2000;
        uint256 _validUntil = block.timestamp + 10 days;

        hevm.prank(subExecutor.getOwner());
        subExecutor.createSubscription(
            address(initiator), 
            _amount, 
            _paymentInterval, 
            _validUntil, 
            _erc20Token
        );

        // Case 3: Caller is not EntryPoint, Owner, or Self (should fail)
        address unauthorizedCaller = address(0x1234);
        hevm.prank(unauthorizedCaller);
        (bool success,) = address(subExecutor).call(abi.encodeWithSelector(
            subExecutor.revokeSubscription.selector,
            address(initiator)
        ));

        // Expecting call to fail
        assert(!success);
    }

    /////////////////////////////////////////////////////////////////////////
    // processPayment
    /////////////////////////////////////////////////////////////////////////

    function test_subscription_validity_initial_interval() public view {       
        for (uint i = 0; i < allSubscribers.length; i++) {
            SubStorage memory sub = subExecutor.getSubscription(allSubscribers[i]);

            // If no payments have been made, ensure that the subscription is still in its initial interval
            // with paymentHistory.length = 0
            assert(block.timestamp < sub.validAfter + sub.paymentInterval || block.timestamp > sub.validUntil);
        }
    }

    // Echidna test to try to break the validity period in SubExecutor's processPayment function
    function test_payment_validity_before_subscription(uint256 _amount, uint256 _paymentInterval) public {
        if (_amount == 0 || _paymentInterval == 0) return;

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

        hevm.prank(address(initiator));
        try subExecutor.processPayment() {
            // If this line is reached, the test should fail
            assert(false);
        } catch {
            // Expected behavior, the transaction should revert
            assert(true);
        }
    }

    // Echidna test to try to break the validity period in SubExecutor's processPayment function
    function test_payment_validity_expired_subscription(uint256 _amount, uint256 _paymentInterval) public {
        if (_amount == 0 || _paymentInterval == 0) return;

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

        // Warp to a time after the subscription has expired
        hevm.warp(_validUntil + 10);
        Debugger.log("timestamp with _validUntil + 10! ", block.timestamp);

        hevm.prank(address(initiator));
        try subExecutor.processPayment() {
            // If this line is reached, the test should fail
            assert(false);
        } catch {
            // Expected behavior, the transaction should revert
            assert(true);
        }
    }

    // Echidna test to try to break the validity period in SubExecutor's processPayment function
    function test_payment_validity_valid_subscription() public {
        uint256 _amount = 25;
        uint256 _paymentInterval = 2000;

        hevm.prank(deployer);
        token.mint(address(subExecutor), 100 ether);

        hevm.prank(address(subExecutor));
        token.approve(address(initiator), 100 ether);

        uint256 _validAfter = block.timestamp + 1 days;
        uint256 _validUntil = _validAfter + 10 days;

        Debugger.log("_validAfter number! ", _validAfter);
        Debugger.log("_validUntil number! ", _validUntil);

        // Registering a subscription
        hevm.prank(address(entryPoint));
        subExecutor.createSubscription(
            address(initiator), 
            _amount, 
            _paymentInterval, 
            _validUntil, 
            _erc20Token
        );

        // Warp to a time within the valid range and ensure it doesn't revert
        hevm.warp(_validAfter + 1);
        hevm.prank(address(initiator));
        try subExecutor.processPayment() {
            // Expected behavior, the transaction should succeed
            assert(true);
        } catch {
            assert(false);
        }
    }
}