// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../SeUpH.sol";


contract HalmosInitiatorTest is SetUpHalmosInitiatorTest {


/////////////////////////////////////////////////////////////////////////
// registerSubscription 
/////////////////////////////////////////////////////////////////////////
    function check_testRegisterSubscriptionFuzz(
        address _subscriber,
        uint256 _amount,
        uint256 _validUntil,
        uint256 _paymentInterval,
        address _erc20Token
    ) public {
        vm.assume(_amount > 0 && _paymentInterval > 0);
        vm.prank(_subscriber);

        initiator.registerSubscription(_subscriber, _amount, _validUntil, _paymentInterval, _erc20Token);

        address[] memory registeredSubscribers = initiator.getSubscribers();
        assertEq(registeredSubscribers[0], _subscriber);

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
// 1. A User may register multiple times
/////////////////////////////////////////////////////////////////////////
    function check_testFuzzMultipleSubscriptions() public {
        address subscriber = holders[0];
        uint256 iterations = 2; 

        for (uint256 i = 0; i < iterations; i++) {

            uint256 amount = uint256(keccak256(abi.encodePacked(block.timestamp, subscriber, i))) % 100 ether;
            uint256 validUntil = block.timestamp + (1 days + i * 1 days);
            uint256 paymentInterval = (1 days + i * 1 hours);

            vm.assume(amount > 0);
            vm.assume(validUntil > block.timestamp);
            vm.assume(paymentInterval > 0);

            vm.prank(subscriber);
            initiator.registerSubscription(subscriber, amount, validUntil, paymentInterval, address(token));
            address[] memory registeredSubscribers = initiator.getSubscribers();
            console.log("Subscriber i",registeredSubscribers[i]);
            console.log("===================");
            assertEq(registeredSubscribers[i], subscriber);
        }
    }

/////////////////////////////////////////////////////////////////////////
// removeSubscription => Removed from mapping but not from address[] public subscribers (X)
/////////////////////////////////////////////////////////////////////////
    function check_testFUZZ_remove(
        address _subscriber,
        uint256 _amount,
        uint256 _validUntil,
        uint256 _paymentInterval,
        address _erc20Token) public {

        vm.assume(_amount > 0 && _paymentInterval > 0);
        vm.startPrank(_subscriber);

        initiator.registerSubscription(_subscriber, _amount, _validUntil, _paymentInterval, _erc20Token);
        initiator.removeSubscription(_subscriber);

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
// registerSubscription Token != ERC20  => erc20TokensValid == true
// We can register any token without any restriction
/////////////////////////////////////////////////////////////////////////

    function check_test_failTokenFalse(
        uint256 amount,
        uint256 _validUntil,
        uint256 paymentInterval,
        address FalseToken) public {

        address subscriber = holders[0];

        vm.assume (1 ether <= amount && amount <= 1000 ether);
        vm.assume (1 days <= paymentInterval && paymentInterval <= 365 days);
        vm.assume (1 days <= _validUntil && _validUntil <= 365 days);
        vm.assume (FalseToken != address(token));

        uint256 validUntil = block.timestamp + _validUntil;
        vm.assume(amount > 0 && paymentInterval > 0 && validUntil > block.timestamp);

        vm.prank(subscriber);
        bool hasFailed = false;
        try initiator.registerSubscription(subscriber, amount, validUntil, paymentInterval, FalseToken) {

        } catch {
            hasFailed = true;
        }

        if (hasFailed) {
            fail("La llamada a registerSubscription ha revertido de manera inesperada.");
        }

        ISubExecutor.SubStorage memory sub = initiator.getSubscription(subscriber);
        assertEq(sub.amount, amount);
        assertEq(sub.validUntil, validUntil);
        assertEq(sub.paymentInterval, paymentInterval);
        assertEq(sub.subscriber, subscriber);
        assertEq(sub.initiator, address(initiator));
        assertEq(sub.erc20Token, address(FalseToken));
        assertEq(sub.erc20TokensValid, FalseToken != address(0));
    }

/////////////////////////////////////////////////////////////////////////
// registerSubscription NoToken ERC20 => address(0) => erc20TokensValid == false
// we can register an address(0)
/////////////////////////////////////////////////////////////////////////

    function check_Address0_failTokenFalse(
        uint256 amount,
        uint256 _validUntil,
        uint256 paymentInterval,
        address address0) public {

        address subscriber = holders[0];

        vm.assume (1 ether <= amount && amount <= 1000 ether);
        vm.assume (1 days <= paymentInterval && paymentInterval <= 365 days);
        vm.assume (1 days <= _validUntil && _validUntil <= 365 days);
        vm.assume (address0 == address(0));

        uint256 validUntil = block.timestamp + _validUntil;
        vm.assume(amount > 0 && paymentInterval > 0 && validUntil > block.timestamp);

        vm.prank(subscriber);
        bool hasFailed = false;
        try initiator.registerSubscription(subscriber, amount, validUntil, paymentInterval, address0) {
        } catch {
            hasFailed = true; 
        }

        if (hasFailed) {
            fail("Revert");
        }

        ISubExecutor.SubStorage memory sub = initiator.getSubscription(subscriber);
        assertEq(sub.amount, amount);
        assertEq(sub.validUntil, validUntil);
        assertEq(sub.paymentInterval, paymentInterval);
        assertEq(sub.subscriber, subscriber);
        assertEq(sub.initiator, address(initiator));
        assertEq(sub.erc20Token, address(address0));
        assertEq(sub.erc20TokensValid, false);
    }

/////////////////////////////////////////////////////////////////////////
// _processNativePayment is never called unless it is address(0)
// 5. Error in storing all variables of the contract when attempting to interact 
// with the initiatePayment function or related functions involving the SubExecutor contract.
/////////////////////////////////////////////////////////////////////////
    function check_test_initiatePayment(
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


}