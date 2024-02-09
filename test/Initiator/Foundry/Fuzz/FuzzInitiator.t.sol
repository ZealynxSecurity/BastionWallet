// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../SetUp.sol";


contract FoundryInitiator_Fuzz_Test is SetUp_F_Initiator {


/////////////////////////////////////////////////////////////////////////
// registerSubscription
/////////////////////////////////////////////////////////////////////////

    function test_check_testRegisterSubscriptionFuzz(
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
        address[] memory registeredSubscribers = initiator.getSubscribers();
        assertEq(registeredSubscribers[0], _subscriber);

      // Verificaciones
        ISubExecutor.SubStorage memory sub = initiator.getSubscription(_subscriber);
        assertEq(sub.amount, _amount);
        assertEq(sub.validUntil, _validUntil);
        assertEq(sub.paymentInterval, _paymentInterval);
        assertEq(sub.subscriber, _subscriber);
        assertEq(sub.initiator, address(initiator));
        assertEq(sub.erc20Token, address(_erc20Token));
        assertEq(sub.erc20TokensValid, _erc20Token != address(0));

}

/////////////////////////////////////////////////////////////////////////
// removeSubscription
/////////////////////////////////////////////////////////////////////////

    function test_check_testFUZZ_remove(
        address _subscriber,
        uint256 _amount,
        uint256 _validUntil,
        uint256 _paymentInterval,
        address _erc20Token) public {

        vm.assume(_amount > 0 && _paymentInterval > 0);
        vm.startPrank(_subscriber);

        // Registrar y luego eliminar la suscripción como el suscriptor
        initiator.registerSubscription(_subscriber, _amount, _validUntil, _paymentInterval, _erc20Token);
        initiator.removeSubscription(_subscriber);

        // Verificaciones
        ISubExecutor.SubStorage memory sub = initiator.getSubscription(_subscriber);
        assertEq(sub.subscriber, address(0));


        address[] memory registeredSubscribers = initiator.getSubscribers();
        bool isSubscriberPresent = false;
        for (uint i = 0; i < registeredSubscribers.length; i++) {
            if (registeredSubscribers[i] == _subscriber) {
                isSubscriberPresent = true;
                break;
            }
        }
        assertFalse(isSubscriberPresent, "Subscriber should be removed from the subscribers array");
    }


/////////////////////////////////////////////////////////////////////////
// registerSubscription NoToken ERC20 => true
/////////////////////////////////////////////////////////////////////////
    function test_primer_failTokenFalse(
        uint256 amount,
        uint256 _validUntil,
        uint256 paymentInterval,
        address FalseToken) public {


        address subscriber = holders[0];
        amount = bound(amount, 1 ether, 1000 ether);
        paymentInterval = bound(paymentInterval, 1 days, 365 days);
        uint256 validUntil = block.timestamp + bound(_validUntil, 1 days, 365 days);
        
        vm.assume (FalseToken != address(token));
        vm.assume(amount > 0 && paymentInterval > 0 && validUntil > block.timestamp);

        // Registrar una suscripción
        vm.prank(subscriber);
        vm.expectRevert();
        initiator.registerSubscription(subscriber, amount, validUntil, paymentInterval, FalseToken);

    }

/////////////////////////////////////////////////////////////////////////
// 5. Error in storing all variables of the contract when attempting to interact 
// with the initiatePayment function or related functions involving the SubExecutor contract.
/////////////////////////////////////////////////////////////////////////
    function test_Fuzz_tinitiatePayment_ActiveSubscription(        
        uint256 amount,
        uint256 paymentInterval,
        address FalseToken) public {


        address subscriber = holders[0];
        uint256 _validAfter = block.timestamp + 1 days;
        uint256 validUntil = _validAfter + 10 days;

        amount = bound(amount, 1 ether, 1000 ether);
        paymentInterval = bound(paymentInterval, 1 days, 365 days);

        vm.prank(subscriber);
        initiator.registerSubscription(subscriber, amount, validUntil, paymentInterval, address(token));

        ISubExecutor.SubStorage memory sub = initiator.getSubscription(subscriber);
        assertEq(sub.amount, amount);
        assertEq(sub.validUntil, validUntil);
        assertEq(sub.paymentInterval, paymentInterval);
        assertEq(sub.subscriber, subscriber);
        assertEq(sub.initiator, address(initiator));
        assertEq(sub.erc20Token, address(FalseToken));
        assertEq(sub.erc20TokensValid, FalseToken != address(0));

        initiator.getSubscription(subscriber);
        //in subExecutor
        initiator.setSubExecutor(address(subExecutor));
        subExecutor.getSubscription(subscriber);

        uint256 warpToTime = _validAfter + 10;
        vm.warp(warpToTime);

        vm.prank(subscriber);
        bool success;
        try initiator.initiatePayment(subscriber) {
            success = true;
        } catch {
            success = false;
        }

        assertTrue(success, "InitiatePayment call successful");
    }

/////////////////////////////////////////////////////////////////////////
// 5. Error in storing all variables of the contract when attempting to interact 
// with the initiatePayment function or related functions involving the SubExecutor contract. => Address(0)
/////////////////////////////////////////////////////////////////////////
    function test_Fuzz_Address0_InitiatePayment(
        uint256 amount,
        uint256 validUntilOffsetDays,
        uint256 paymentIntervalDays,
        uint256 tokenAmount,
        address FalseToken
    ) public {
        // Ensure reasonable input values.
        vm.assume(amount > 0 && amount <= 100 ether);
        vm.assume(validUntilOffsetDays >= 1 && validUntilOffsetDays <= 365);
        vm.assume(paymentIntervalDays >= 1 && paymentIntervalDays <= validUntilOffsetDays);
        vm.assume(tokenAmount > amount && tokenAmount <= 1000 ether);
        FalseToken = address(0);

        address subscriber = deployer;
        uint256 _validAfter = block.timestamp + 1 days;
        uint256 validUntil = _validAfter + validUntilOffsetDays * 1 days;
        uint256 paymentInterval = paymentIntervalDays * 1 days;

        // Transfer tokens to the Initiator contract as part of the test setup.
        uint256 tokenBalance = amount + tokenAmount;
        vm.startPrank(deployer);
        token.mint(address(subExecutor), tokenBalance);
        vm.stopPrank();

        // Approve Initiator to spend tokens on behalf of SubExecutor.
        vm.startPrank(address(subExecutor));
        token.approve(address(initiator), tokenBalance);
        vm.stopPrank();

        // Register the subscription with fuzzing parameters.
        vm.prank(subscriber);
        initiator.registerSubscription(subscriber, amount, validUntil, paymentInterval, address(FalseToken));
        initiator.setSubExecutor(address(subExecutor));

        // Advance to the time when the subscription is active but not expired.
        uint256 warpToTime = _validAfter + (validUntilOffsetDays / 2) * 1 days; // Halfway to ensure it's active.
        vm.warp(warpToTime);

        // Attempt to initiate a payment as the subscriber.
        vm.prank(subscriber);
        bool success;
        try initiator.initiatePayment(subscriber) {
            success = true;
        } catch {
            success = false;
        }

        assertTrue(success, "The call to initiatePayment should have been successful");
    }

/////////////////////////////////////////////////////////////////////////
// 5. Error in storing all variables of the contract when attempting to interact 
// with the initiatePayment function or related functions involving the SubExecutor contract.
/////////////////////////////////////////////////////////////////////////

    function test_FuzzInitiatePayment(
        uint256 amount,
        uint256 validUntilOffsetDays,
        uint256 paymentIntervalDays,
        uint256 tokenAmount
    ) public {
        // Ensure reasonable input values.
        vm.assume(amount > 0 && amount <= 100 ether);
        vm.assume(validUntilOffsetDays >= 1 && validUntilOffsetDays <= 365);
        vm.assume(paymentIntervalDays >= 1 && paymentIntervalDays <= validUntilOffsetDays);
        vm.assume(tokenAmount > amount && tokenAmount <= 1000 ether);

        address subscriber = deployer;
        uint256 _validAfter = block.timestamp + 1 days;
        uint256 validUntil = _validAfter + validUntilOffsetDays * 1 days;
        uint256 paymentInterval = paymentIntervalDays * 1 days;

        // Transfer tokens to the Initiator contract as part of the test setup.
        uint256 tokenBalance = amount + tokenAmount;
        vm.startPrank(deployer);
        token.mint(address(subExecutor), tokenBalance);
        vm.stopPrank();

        // Approve Initiator to spend tokens on behalf of SubExecutor.
        vm.startPrank(address(subExecutor));
        token.approve(address(initiator), tokenBalance);
        vm.stopPrank();

        // Register the subscription with fuzzing parameters.
        vm.prank(subscriber);
        initiator.registerSubscription(subscriber, amount, validUntil, paymentInterval, address(token));
        initiator.setSubExecutor(address(subExecutor));

        // Advance to the time when the subscription is active but not expired.
        uint256 warpToTime = _validAfter + (validUntilOffsetDays / 2) * 1 days; // Halfway to ensure it's active.
        vm.warp(warpToTime);

        // Attempt to initiate a payment as the subscriber.
        vm.prank(subscriber);
        bool success;
        try initiator.initiatePayment(subscriber) {
            success = true;
        } catch {
            success = false;
        }

        assertTrue(success, "The call to initiatePayment should have been successful");
    }

/////////////////////////////////////////////////////////////////////////
// 5. Error in storing all variables of the contract when attempting to interact 
// with the initiatePayment function or related functions involving the SubExecutor contract.
/////////////////////////////////////////////////////////////////////////

    function test_payment_validity_period(uint256 _amount, uint256 _paymentInterval) public {
        if(_amount == 0 || _paymentInterval == 0) return;

        uint256 _validAfter = block.timestamp + 1 days;
        uint256 _validUntil = _validAfter + 10 days;
        address subscriber = holders[0];

        // Registering a subscription
        vm.prank(subscriber);
        initiator.registerSubscription(subscriber, _amount, _validUntil, _paymentInterval, address(token));

        // Warp to a time before the subscription is valid
        vm.warp(_validAfter - 10);
        vm.prank(subscriber);
        try initiator.initiatePayment(subscriber) {
            // If this line is reached, the test should fail
            assert(false);
        } catch {
            // Expected behavior, the transaction should revert
        }

        // Warp to a time after the subscription has expired
        vm.warp(_validUntil + 10);
        vm.prank(subscriber);
        try initiator.initiatePayment(subscriber) {
            // If this line is reached, the test should fail
            assert(false);
        } catch {
            // Expected behavior, the transaction should revert
        }

        // Warp to a time within the valid range and ensure it doesn't revert
        vm.warp(_validAfter + 1);
        vm.prank(subscriber);
        try initiator.initiatePayment(subscriber) {
            // Expected behavior, the transaction should succeed
        } catch {
            assert(false);
        }
    }

/////////////////////////////////////////////////////////////////////////
// 1. A User may register multiple times
/////////////////////////////////////////////////////////////////////////
    function test_subscription_multiple_registration() public {
        uint256 _amount = 1;
        uint256 _validUntil = 5;
        uint256 _paymentInterval = 1;
        uint256 repeat = 500000;

        for (uint256 index; index < repeat; index++) {
            vm.prank(deployer);
            console.log("Gas Left: ", gasleft());
            initiator.registerSubscription(deployer, _amount, _validUntil, _paymentInterval, address(token));
        }
    }

}
