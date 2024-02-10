// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../../../SetUp/SetUp_Foundry.sol";

contract SFoundrySubExecutor_Unit_Test is SetUp_Foundry {



/////////////////////////////////////////////////////////////////////////
// CreateSub
/////////////////////////////////////////////////////////////////////////

    function testCreateSubscription() public {
        uint256 amount = 1 ether;
        uint256 interval = 30 days;
        uint256 validUntil = block.timestamp + 90 days;
        address erc20Token = address(token);

        address owner = subExecutor.getOwner();
        vm.prank(owner);
        console.log("owner", owner);
        subExecutor.createSubscription(address(initiator), amount, interval, validUntil, erc20Token);

        // Verificar que la suscripción se haya creado correctamente
        SubStorage memory sub = subExecutor.getSubscription(address(initiator));
        uint256 amountr =  sub.amount;
        uint256 intervalr = sub.paymentInterval;
        uint256 validuntilr = sub.validUntil;

        // conole.log("amount", amountr);
        console.log("interval", intervalr);
        console.log("validUntil", validuntilr);

        assertEq(sub.amount, amount);
        assertEq(sub.paymentInterval, interval);
        assertEq(sub.validUntil, validUntil);
        assertEq(sub.erc20Token, erc20Token);
    }

// /////////////////////////////////////////////////////////////////////////
// // Valor block.timestamp -1 => validUntil = 0
// /////////////////////////////////////////////////////////////////////////
    function testFuzzSubscriptionNegative() public {
        uint256 amount = 1 ether;
        uint256 interval = 30 days;
        uint256 validUntil = block.timestamp -1 ;

        console.log("Value", validUntil);

        address owner = subExecutor.getOwner();
        vm.startPrank(owner);
        subExecutor.createSubscription(address(initiator), amount, interval, validUntil, address(token));

        SubStorage memory sub = subExecutor.getSubscription(address(initiator));
        uint256 valid = sub.validUntil;
        console.log("Value", valid);
        assertEq(sub.validUntil, validUntil);
    }

// /////////////////////////////////////////////////////////////////////////
// // RevokeSubscription and time
// /////////////////////////////////////////////////////////////////////////

    function testFuzzRevokeSubscription() public {

        // Setting up a subscription
        address owner = subExecutor.getOwner();
        vm.startPrank(owner);
        subExecutor.createSubscription(address(initiator), 1 ether, 30 days, block.timestamp + 90 days, address(token));

        // Revoke the subscription
        subExecutor.revokeSubscription(address(initiator));

        // Verify that the subscription has been revoked
        SubStorage memory sub = subExecutor.getSubscription(address(initiator));
        assertEq(sub.initiator, address(0)); // Or any other verification that the subscription was revoked
    }

// /////////////////////////////////////////////////////////////////////////
// // revert: Subscription expired
// /////////////////////////////////////////////////////////////////////////

    function test_initiatePayment_ActiveSubscription() public {
        address subscriber = deployer;
        uint256 amount = 1 ether;
        uint256 _validAfter = block.timestamp + 1 days;
        uint256 validUntil = _validAfter + 10 days;
        uint256 paymentInterval = 10 days;


        uint256 tokenAmount = 10 ether;
        vm.prank(subscriber);
        token.transfer(address(initiator), tokenAmount);

        // Register the subscription
        vm.prank(subscriber);
        initiator.registerSubscription(subscriber, amount, validUntil, paymentInterval, address(token));

        // Advance to the time when the subscription is active but not expired
        uint256 warpToTime = _validAfter + 10;
        vm.warp(warpToTime);

        // Attempt to initiate a payment
        vm.prank(subscriber);
        bool success;
        try subExecutor.processPayment() {
            success = false;
        } catch {
            success = true;
        }

        assertTrue(success, "The call to initiatePayment should have failed");
    }

}