// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../../../SetUp/SetUp_Foundry.sol";

contract SFoundrySubExecutor_Fuzz_Test is SetUp_Foundry {


/////////////////////////////////////////////////////////////////////////
// CreateSub
/////////////////////////////////////////////////////////////////////////
    function testFuzzCreateSub(
        uint256 amount,
        uint256 validUntil,
        uint256 interval
    ) public {

        vm.assume (amount < type(uint256).max && validUntil < type(uint256).max && interval < type(uint256).max);
    
        address owner = subExecutor.getOwner();
        vm.startPrank(owner);
        try subExecutor.createSubscription(
            address(initiator), amount, validUntil, interval, address(token)
        ) {
            assertTrue(true);
        } catch Error(string memory reason) {
            // Assert failure reason
            assertEq(reason, "Subscription amount is 0"); 
            emit log("Create sub failed!");
        }
        vm.stopPrank();
    }

    function testFuzzCreateSubscription(uint256 amount, uint256 interval, uint256 validUntilOffset, address erc20Token) public {
        // Asegurarse de que las entradas sean manejables para la prueba
        amount = bound(amount, 1 ether, 1000 ether);
        interval = bound(interval, 1 days, 365 days);
        uint256 validUntil = block.timestamp + bound(validUntilOffset, 1 days, 365 days);

        vm.assume(amount > 0 && interval > 0 && validUntil > block.timestamp);
        address owner = subExecutor.getOwner();
        vm.startPrank(owner);
        subExecutor.createSubscription(address(initiator), amount, interval, validUntil, erc20Token);

        // Verificar que la suscripción se haya creado correctamente
        SubStorage memory sub = subExecutor.getSubscription(address(initiator));
        assertTrue(sub.amount == amount && sub.paymentInterval == interval && sub.validUntil == validUntil);
    }

// /////////////////////////////////////////////////////////////////////////
// // Valor muy lejana en block.timestamp: _validUntil
// /////////////////////////////////////////////////////////////////////////

    function testFuzzSubscriptionExtremeDates(uint256 validUntilOffset) public {
        uint256 amount = 1 ether;
        uint256 interval = 30 days;
        uint256 validUntil = block.timestamp + bound(validUntilOffset, 1 days, 10000 days); // Fecha muy lejana en el futuro

        vm.assume(validUntil > block.timestamp);
        address owner = subExecutor.getOwner();
        vm.startPrank(owner);
        subExecutor.createSubscription(address(initiator), amount, interval, validUntil, address(token));

        // Verificar que la suscripción se haya creado correctamente con fechas extremas
        SubStorage memory sub = subExecutor.getSubscription(address(initiator));
        assertEq(sub.validUntil, validUntil);
    }



// /////////////////////////////////////////////////////////////////////////
// // ModifiSub param: _interval
// /////////////////////////////////////////////////////////////////////////

    function testFuzzModifySub(uint256 amount, uint256 interval, uint256 newinterval, uint256 validUntilOffset) public {

        interval = bound(interval, 1 days, 365 days);
        newinterval = bound(newinterval, 1 days, 365 days);
        uint256 validUntil = block.timestamp + bound(validUntilOffset, 1 days, 365 days);
        vm.assume(amount > 0 && interval > 0 && validUntil > block.timestamp);

        address owner = subExecutor.getOwner();
        vm.startPrank(owner);
        subExecutor.createSubscription(address(initiator), amount, interval, validUntil, address(token));

        try subExecutor.modifySubscription(
            address(initiator),
            amount,
            newinterval,
            validUntil,
            address(token)
        ) {    
            assertTrue(true);
        } catch Error(string memory reason) {
            emit log("Modify sub failed!");
        }
        vm.stopPrank();


        SubStorage memory sub = subExecutor.getSubscription(address(initiator));

        assertEq(sub.amount, amount);
        assertEq(sub.validUntil, validUntil);
        assertEq(sub.paymentInterval, newinterval);

    }

// /////////////////////////////////////////////////////////////////////////
// // ModifiSub param: 
// /////////////////////////////////////////////////////////////////////////

    function testFuzzModifySubscription(uint256 amount, uint256 interval, uint256 validUntilOffset) public {
        // Configuración inicial
        uint256 initialAmount = 10 ether;
        uint256 initialInterval = 30 days;
        uint256 initialValidUntil = block.timestamp + 60 days;

        address owner = subExecutor.getOwner();
        vm.startPrank(owner);
        subExecutor.createSubscription(address(initiator), initialAmount, initialInterval, initialValidUntil, address(token));

        // Fuzzing
        amount = bound(amount, 1 ether, 1000 ether);
        interval = bound(interval, 1 days, 365 days);
        uint256 validUntil = block.timestamp + bound(validUntilOffset, 1 days, 365 days);

        vm.assume(amount > 0 && interval > 0 && validUntil > block.timestamp);

        subExecutor.modifySubscription(address(initiator), amount, interval, validUntil, address(token));
        vm.stopPrank();
        // Verificación
        SubStorage memory sub = subExecutor.getSubscription(address(initiator));
        assertTrue(sub.amount == amount && sub.paymentInterval == interval && sub.validUntil == validUntil);
}



// /////////////////////////////////////////////////////////////////////////
// // 6. _processERC20Payment Logic Flaw: Incorrect Token Transfer
// /////////////////////////////////////////////////////////////////////////

//2º igua
    function test_FuzzERC20Payment(uint256 tokenBalance, uint256 paymentAmount) public {
        // Ensure reasonable input values.
        vm.assume(tokenBalance >= 1 ether && tokenBalance <= 1000 ether);
        vm.assume(paymentAmount >= 1 wei && paymentAmount <= tokenBalance);

        // Mint tokens to SubExecutor and set the allowance for Initiator.
        vm.startPrank(deployer);
        token.mint(address(subExecutor), tokenBalance);
        vm.stopPrank();

        // SubExecutor approves Initiator to spend tokens on its behalf.
        vm.startPrank(address(subExecutor));
        token.approve(address(initiator), tokenBalance);
        vm.stopPrank();

        // Save initial balances of SubExecutor and Initiator for comparison later.
        uint256 subExecutorBalanceBefore = token.balanceOf(address(subExecutor));
        uint256 initiatorBalanceBefore = token.balanceOf(address(initiator));

        // Set up a subscription in SubExecutor for the Initiator.
        address owner = subExecutor.getOwner();
        uint256 validAfter = block.timestamp;
        uint256 validUntil = block.timestamp + 90 days;

        vm.startPrank(owner);
        subExecutor.createSubscription(address(initiator), paymentAmount, 30 days, validUntil, address(token));
        vm.stopPrank();

        // Warp time to meet the payment interval.
        vm.warp(validAfter + 30 days + 1);

        // Process the payment as the Initiator.
        vm.prank(address(initiator));
        subExecutor.processPayment(); // Assume processPayment does not require arguments.

        // Verify balances after payment.
        uint256 subExecutorBalanceAfter = token.balanceOf(address(subExecutor));
        uint256 initiatorBalanceAfter = token.balanceOf(address(initiator));

        // Assertions to verify the correct transfer of tokens.
        assertEq(subExecutorBalanceAfter, subExecutorBalanceBefore - paymentAmount, "SubExecutor's balance should decrease by the payment amount.");
        assertEq(initiatorBalanceAfter, initiatorBalanceBefore + paymentAmount, "Initiator's balance should increase by the payment amount.");

    }


// /////////////////////////////////////////////////////////////////////////
// // revert: Subscription expired
// /////////////////////////////////////////////////////////////////////////
    function test_ree_initiatePayment(
        uint256 amount,
        uint256 _validUntil,
        uint256 paymentInterval,
        address FalseToken
    ) public {
        // Definir los límites de los parámetros de entrada.
        uint256 boundAmount = bound(amount, 1 ether, 1000 ether);
        uint256 boundValidUntil = bound(_validUntil, 1 days, 365 days);
        uint256 boundPaymentInterval = bound(paymentInterval, 1 days, 365 days);

        // Ajustar 'validUntil' para que esté dentro del rango deseado desde ahora.
        uint256 validUntil = block.timestamp + boundValidUntil;

        // Configuración inicial y registro de la suscripción.
        address subscriber = holders[0];
        vm.startPrank(subscriber);
        initiator.registerSubscription(subscriber, boundAmount, validUntil, boundPaymentInterval, FalseToken);
            console.log("subscriber:", subscriber);
            console.log(" amount:", boundAmount);
            console.log("validUntil:", validUntil);
        vm.stopPrank();
        
        uint256 warpToTime = block.timestamp + 1 days;
        vm.assume(warpToTime > block.timestamp && warpToTime < validUntil);
        vm.warp(warpToTime);
        // Intentar iniciar un pago.
        address owner = subExecutor.getOwner();

        vm.prank(owner);
        bool success = true;
        try subExecutor.processPayment() {
            // Intencionadamente vacío.
        } catch {
            success = false;
        }
        assert(success);
    }



// /////////////////////////////////////////////////////////////////////////
// // Subscription Dates
// /////////////////////////////////////////////////////////////////////////

function testFuzzSubscriptionDates(uint256 validUntilOffset, uint256 paymentInterval) public {
    uint256 validUntil = block.timestamp + bound(validUntilOffset, 1 days, 3650 days);
    paymentInterval = bound(paymentInterval, 1 days, 365 days);

    vm.assume(validUntil > block.timestamp && paymentInterval > 0);

    address owner = subExecutor.getOwner();
    vm.prank(owner);
    subExecutor.createSubscription(address(initiator), 1 ether, paymentInterval, validUntil, address(token));

    // Verificar que las fechas se hayan establecido correctamente
    SubStorage memory sub = subExecutor.getSubscription(address(initiator));
    assertEq(sub.validUntil, validUntil);
    assertEq(sub.paymentInterval, paymentInterval);
}

// /////////////////////////////////////////////////////////////////////////
// // Access Control
// /////////////////////////////////////////////////////////////////////////

function testFuzzAccessControlDifferentRoles(address caller, bool isOwnerOrEntryPoint) public {
    vm.assume(caller != address(0));

    if (isOwnerOrEntryPoint) {
        // Simular que el llamante es el propietario o el punto de entrada
        address owner = subExecutor.getOwner();
        vm.prank(owner);
        subExecutor.createSubscription(address(initiator), 1 ether, 30 days, block.timestamp + 90 days, address(token));
    } else {
        // Simular que el llamante no es el propietario o el punto de entrada
        vm.prank(caller);
        vm.expectRevert("account: not from entrypoint or owner or self");
        subExecutor.createSubscription(address(initiator), 1 ether, 30 days, block.timestamp + 90 days, address(token));
    }
}


}
