// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../../../SetUp/SetUp_Foundry.sol";


contract FoundryInitiator_Unit_Test is SetUp_Foundry {


/////////////////////////////////////////////////////////////////////////
// registerSubscription
/////////////////////////////////////////////////////////////////////////

 function test_RegisterSubscription() public {
        address subscriber = holders[0];
        uint256 amount = 1 ether;
        uint256 validUntil = block.timestamp + 30 days;
        uint256 paymentInterval = 10 days;

        vm.prank(subscriber);
        initiator.registerSubscription(subscriber, amount, validUntil, paymentInterval, address(token));

        ISubExecutor.SubStorage memory sub = initiator.getSubscription(subscriber);
        assertEq(sub.amount, amount);
        assertEq(sub.validUntil, validUntil);
        assertEq(sub.paymentInterval, paymentInterval);
        assertEq(sub.subscriber, subscriber);
        assertEq(sub.initiator, address(initiator));
        assertEq(sub.erc20Token, address(token));

        console.log("Token Supply",token.totalSupply());
        console.log("Address Token Balance",address(token).balance);

        address[] memory registeredSubscribers = initiator.getSubscribers();
        assertEq(registeredSubscribers[0], subscriber);
    }

// /////////////////////////////////////////////////////////////////////////
// 1. A User may register multiple times
// /////////////////////////////////////////////////////////////////////////

    function test_fail_RegisterSubscriptionIfSubscriptionExists() public { 
        address subscriber = holders[0];
        uint256 amount = 1 ether;
        uint256 validUntil = block.timestamp + 30 days;
        uint256 paymentInterval = 10 days;

        vm.prank(subscriber);
        initiator.registerSubscription(subscriber, amount, validUntil, paymentInterval, address(token));

        vm.expectRevert();
        vm.prank(subscriber);
        initiator.registerSubscription(subscriber, amount, validUntil, paymentInterval, address(token));
    }

/////////////////////////////////////////////////////////////////////////
// 1. A User may register multiple times
/////////////////////////////////////////////////////////////////////////
    function testFuzzMultipleSubscriptions() public {
        address subscriber = holders[0];
        uint256 iterations = 5;

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
// The user is registered in different memory locations.
/////////////////////////////////////////////////////////////////////////

    function testFuzzxcMultipleSubscriptions() public {
        address subscriber = holders[0];
        uint256 iterations = 5; 

        for (uint256 i = 0; i < iterations; i++) {
            uint256 amount = uint256(keccak256(abi.encodePacked(block.timestamp, subscriber, i))) % 100 ether;
            uint256 validUntil = block.timestamp + (1 days + i * 1 days);
            uint256 paymentInterval = (1 days + i * 1 hours);

            vm.assume(amount > 0);
            vm.assume(validUntil > block.timestamp);
            vm.assume(paymentInterval > 0);
            vm.prank(subscriber);

            initiator.registerSubscription(subscriber, amount, validUntil, paymentInterval, address(token));

            console.log("subscriber:", subscriber);
            console.log(" amount:", amount);
            console.log("validUntil:", validUntil);
        }

        address[] memory registeredSubscribers = initiator.getSubscribers();
        assertTrue(registeredSubscribers.length <= 1, "Should not allow multiple registrations for the same subscriber");

        for (uint256 i = 1; i < registeredSubscribers.length; i++) {
            console.log("registeredSubscribers[i - 1]:", registeredSubscribers[i - 1]);
            console.log("registeredSubscribers[i]:", registeredSubscribers[i]);
            assertTrue(registeredSubscribers[i - 1] != registeredSubscribers[i], "No duplicate subscribers should exist");
        }
    }

/////////////////////////////////////////////////////////////////////////
// You can register any address => The test passes as it has no requirement to do so (X)
/////////////////////////////////////////////////////////////////////////

    function test_failTokenFalse() public { 
        address subscriber = holders[0];
        uint256 amount = 1 ether;
        uint256 validUntil = block.timestamp + 30 days;
        uint256 paymentInterval = 10 days;
        address tokenFalso =  address(this);

        vm.prank(subscriber);
        vm.expectRevert();
        initiator.registerSubscription(subscriber, amount, validUntil, paymentInterval, tokenFalso);

    }

// /////////////////////////////////////////////////////////////////////////
// // 2.1 removeSubscription => Removed from mapping but not from address[] public subscribers (X)
// /////////////////////////////////////////////////////////////////////////

    function test_RemoveSubscription() public {
        address subscriber = holders[0];
        uint256 amount = 1 ether;
        uint256 validUntil = block.timestamp + 30 days;
        uint256 paymentInterval = 10 days;

        vm.prank(subscriber);
        initiator.registerSubscription(subscriber, amount, validUntil, paymentInterval, address(token));
        vm.prank(subscriber);
        initiator.removeSubscription(subscriber);

        ISubExecutor.SubStorage memory sub = initiator.getSubscription(subscriber);
        assertEq(sub.subscriber, address(0));

        address[] memory registeredSubscribers = initiator.getSubscribers();
        bool isSubscriberPresent = false;
        for (uint i = 0; i < registeredSubscribers.length; i++) {
            if (registeredSubscribers[i] == subscriber) {
                isSubscriberPresent = true;
                break;
            }
        }
        assertFalse(isSubscriberPresent, "Subscriber should be removed from the subscribers array");
    }

// /////////////////////////////////////////////////////////////////////////
// // 2.2 removeSubscription => Removed from mapping but not from address[] public subscribers (X)
// /////////////////////////////////////////////////////////////////////////

    function test_frRemoveSubscription() public {
        address subscriber = holders[0];
        uint256 amount = 1 ether;
        uint256 validUntil = block.timestamp + 30 days;
        uint256 paymentInterval = 10 days;

        vm.prank(subscriber);
        initiator.registerSubscription(subscriber, amount, validUntil, paymentInterval, address(token));
        console.log("subscriber:", subscriber);
        console.log(" amount:", amount);
        console.log("validUntil:", validUntil);
        console.log("=================");

        uint256 subscribersCountBefore = initiator.getSubscribers().length;
        console.log("Subscribers count before removal:", subscribersCountBefore);

        vm.prank(subscriber);
        initiator.removeSubscription(subscriber);
        console.log("Subscriber removed:", subscriber);

        // Verifications in the `mapping`
        ISubExecutor.SubStorage memory sub = initiator.getSubscription(subscriber);
        console.log("Subscriber",sub.subscriber);
        assertTrue(sub.subscriber == address(0), "The subscriber field should be reset");

        // Verifications in the `subscribers` array
        address[] memory registeredSubscribers = initiator.getSubscribers();
        uint256 subscribersCountAfter = registeredSubscribers.length;
        console.log("Subscribers count after removal:", subscribersCountAfter);

        assertTrue(subscribersCountBefore - 1 == subscribersCountAfter, "The subscribers count should decrease by one");

        for (uint i = 0; i < subscribersCountAfter; i++) {
            assertTrue(registeredSubscribers[i] != subscriber, "The removed subscriber should not be in the list");
            console.log("Subscriber at position", i, ":", registeredSubscribers[i]);
        }
    }


/////////////////////////////////////////////////////////////////////////
// withdrawETH
/////////////////////////////////////////////////////////////////////////

    function test_WithdrawETH() public { //OK
        // Configuration: Sending ETH to the contract
        uint initialOwnerBalanceA = address(deployer).balance;
        uint InitiatorB = address(initiator).balance;
        console.log("initialOwnerBalanceA",initialOwnerBalanceA);
        console.log("InitiatorB",InitiatorB);
        console.log("===========");

        uint256 amount = 1 ether;
        payable(address(initiator)).transfer(amount);

        // Owner balance before withdrawal
        uint256 ownerBalanceBefore = address(deployer).balance;
        uint256 contractBalanceBefore = address(initiator).balance;
        console.log("initialOwnerBalance",ownerBalanceBefore);
        console.log("InitiatorD",contractBalanceBefore);
        console.log("===========");

        // Withdraw ETH as owner
        vm.prank(deployer);
        initiator.withdrawETH();

        // Verifications
        uint256 ownerBalanceAfter = address(deployer).balance;
        uint256 contractBalanceAfter = address(initiator).balance;
        console.log("finalOwnerBalance",ownerBalanceAfter);
        console.log("InitiatorF",contractBalanceAfter);

        assertEq(ownerBalanceAfter, ownerBalanceBefore + amount);
        assertEq(contractBalanceAfter, contractBalanceBefore - amount);
    }

// /////////////////////////////////////////////////////////////////////////
// // withdrawETH No Owner
// /////////////////////////////////////////////////////////////////////////
    function test_TfailWithdrawETHByNonOwner() public { //OK
        // Configuration: Sending ETH to the contract
        uint256 amount = 1 ether;
        payable(address(initiator)).transfer(amount);

        // Attempt to withdraw ETH as a non-owner
        address nonOwner = holders[0];
        vm.prank(nonOwner);
        vm.expectRevert();
        initiator.withdrawETH(); 
    }

// /////////////////////////////////////////////////////////////////////////
// // withdrawERC20
// /////////////////////////////////////////////////////////////////////////

    function test_WithdrawERC20() public {
        // Configuration: Sending ERC20 tokens to the contract
        uint initialOwnerBalanceA = address(deployer).balance;
        uint InitiatorB = address(initiator).balance;
        console.log("initialOwnerBalanceA",initialOwnerBalanceA);
        console.log("InitiatorB",InitiatorB);

        uint256 tokenAmount = 10 ether;
        vm.prank(deployer);
        token.transfer(address(initiator), tokenAmount);

        // Owner and contract token balances before withdrawal
        uint256 ownerTokenBalanceBefore = token.balanceOf(deployer);
        uint256 contractTokenBalanceBefore = token.balanceOf(address(initiator));
        console.log("initialOwnerBalanceA",ownerTokenBalanceBefore);
        console.log("InitiatorB",contractTokenBalanceBefore);

        // Withdraw ERC20 tokens as owner
        vm.prank(deployer);
        initiator.withdrawERC20(address(token));

        // Verifications
        uint256 ownerTokenBalanceAfter = token.balanceOf(deployer);
        uint256 contractTokenBalanceAfter = token.balanceOf(address(initiator));
        console.log("initialOwnerBalanceA",ownerTokenBalanceAfter);
        console.log("InitiatorB",contractTokenBalanceAfter);

        assertEq(ownerTokenBalanceAfter, ownerTokenBalanceBefore + tokenAmount, "Owner token balance incorrect after withdrawal");
        assertEq(contractTokenBalanceAfter, contractTokenBalanceBefore - tokenAmount, "Contract token balance incorrect after withdrawal");
    }

// /////////////////////////////////////////////////////////////////////////
// // withdrawERC20 No Owner
// /////////////////////////////////////////////////////////////////////////

function test_failWithdrawERC20By_NonOwner() public {
    // Configuration: Sending ERC20 tokens to the contract
    uint256 tokenAmount = 10 ether;
    vm.prank(deployer);
    token.transfer(address(initiator), tokenAmount);

    // Attempting to withdraw ERC20 tokens as non-owner
    address nonOwner = holders[0];
    vm.prank(nonOwner);
    vm.expectRevert();
    initiator.withdrawERC20(address(token)); // This should fail
}

// /////////////////////////////////////////////////////////////////////////
// // initiatePayment => Subscription is not active
// /////////////////////////////////////////////////////////////////////////

    function testFail_initiatePayment_ExpiredSubscription() public {
        address subscriber = holders[0];
        uint256 amount = 1 ether;
        uint256 validUntil = block.timestamp + 30 days;
        uint256 paymentInterval = 10 days;

        // Registering the subscription as the subscriber
        vm.prank(subscriber);
        initiator.registerSubscription(subscriber, amount, validUntil, paymentInterval, address(token));

        // Advancing time for the subscription to expire
        vm.warp(block.timestamp + 31 days);

        // Attempting to initiate a payment (should fail because the subscription expired)
        vm.expectRevert("Subscription is not active");
        initiator.initiatePayment(subscriber);
    }


/////////////////////////////////////////////////////////////////////////
// 5. Error in storing all variables of the contract when attempting to interact 
// with the initiatePayment function or related functions involving the SubExecutor contract.
/////////////////////////////////////////////////////////////////////////

    function test_initiatePayment_ActiveSubscription() public {
        address subscriber = deployer;
        uint256 amount = 1 ether;
        uint256 _validAfter = block.timestamp + 1 days;
        uint256 validUntil = _validAfter + 10 days;
        uint256 paymentInterval = 10 days;


        uint256 tokenAmount = 10 ether;
        vm.prank(subscriber);
        token.transfer(address(initiator), tokenAmount);

        // Registrar la suscripción
        vm.prank(subscriber);
        initiator.registerSubscription(subscriber, amount, validUntil, paymentInterval, address(token));

        // Avanzar al momento en que la suscripción está activa pero no ha expirado
        uint256 warpToTime = _validAfter + 10;
        vm.warp(warpToTime);

        // Intentar iniciar un pago
        vm.prank(subscriber);
        bool success;
        try initiator.initiatePayment(subscriber) {
            success = false;
        } catch {
            success = true;
        }

        assertTrue(success, "La llamada a initiatePayment haber sido exitosa");
    }
}