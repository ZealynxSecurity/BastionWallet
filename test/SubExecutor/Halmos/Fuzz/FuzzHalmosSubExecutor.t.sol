// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../../../SetUp/SetUp_Halmos.sol";

contract HalmosSubExecutor_Fuzz_Test is SetUp_Halmos {


/////////////////////////////////////////////////////////////////////////
// CreateSub
/////////////////////////////////////////////////////////////////////////

    function ckeck_testFuzzCreateSub(
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

/////////////////////////////////////////////////////////////////////////
// CreateSub
/////////////////////////////////////////////////////////////////////////

    function check_testFuzzCreateSubscription(uint256 interval, uint256 validUntilOffset, address erc20Token) public {

        uint256 amount = svm.createUint256("amount");
        uint256 interval = svm.createUint256("interval");
        uint256 validUntilOffset = svm.createUint256("validUntilOffset");

        vm.assume (1 ether <= amount && amount <= 1000 ether);
        vm.assume (1 days <= interval && interval <= 365 days);
        vm.assume (1 days <= validUntilOffset && validUntilOffset <= 365 days);

        uint256 validUntil = block.timestamp + validUntilOffset;

        vm.assume(amount > 0 && interval > 0 && validUntil > block.timestamp);
        address owner = subExecutor.getOwner();
        vm.startPrank(owner);
        subExecutor.createSubscription(address(initiator), amount, interval, validUntil, erc20Token);
        vm.stopPrank();

        SubStorage memory sub = subExecutor.getSubscription(address(initiator));
        assertTrue(sub.amount == amount && sub.paymentInterval == interval && sub.validUntil == validUntil);
    }


// /////////////////////////////////////////////////////////////////////////
// // Very far value in block.timestamp: _validUntil Is any date valid?
// /////////////////////////////////////////////////////////////////////////

    function check_testFuzzSubscriptionExtremeDates(uint256 validUntilOffset) public {
        uint256 amount = 1 ether;
        uint256 interval = 30 days;
       vm.assume (1 days <= validUntilOffset && validUntilOffset <= 365 days);

        uint256 validUntil = block.timestamp + validUntilOffset;

        vm.assume(validUntil > block.timestamp);
        address owner = subExecutor.getOwner();
        vm.startPrank(owner);
        subExecutor.createSubscription(address(initiator), amount, interval, validUntil, address(token));

        SubStorage memory sub = subExecutor.getSubscription(address(initiator));
        assertEq(sub.validUntil, validUntil);
    }


// /////////////////////////////////////////////////////////////////////////
// // Negative value block.timestamp -1 in parameter validUntil
// /////////////////////////////////////////////////////////////////////////

    event argumento(uint256 indexed valid);

    function check_testFuzzSubscriptionNegative(uint256 validUntilOffset) public {
        uint256 amount = 1 ether;
        uint256 interval = 30 days;
       vm.assume (1 days <= validUntilOffset && validUntilOffset <= 365 days);

        uint256 validUntil = block.timestamp - validUntilOffset;
        
        vm.assume(validUntil < block.timestamp);
        address owner = subExecutor.getOwner();
        vm.startPrank(owner);
        subExecutor.createSubscription(address(initiator), amount, interval, validUntil, address(token));

        SubStorage memory sub = subExecutor.getSubscription(address(initiator));
        uint256 valid = sub.validUntil;
        console2.log("ARGUMENT", valid);
        emit argumento(valid);
        assertEq(sub.validUntil, validUntil);
    }



// /////////////////////////////////////////////////////////////////////////
// // ModifiSub param: _interval Any restrictions ?
// /////////////////////////////////////////////////////////////////////////

    function check_testFuzzModifyInterval(uint256 amount, uint256 interval, uint256 newinterval, uint256 validUntilOffset) public {

        uint256 amount = svm.createUint256("amount");
        uint256 interval = svm.createUint256("interval");
        uint256 newinterval = svm.createUint256("newinterval");
        uint256 validUntilOffset = svm.createUint256("validUntilOffset");


        vm.assume (1 ether <= amount && amount <= 1000 ether);
        vm.assume (1 days <= interval && interval <= 365 days);
        vm.assume (1 days <= newinterval && newinterval <= 365 days);
        vm.assume (1 days <= validUntilOffset && validUntilOffset <= 365 days);

        uint256 validUntil = block.timestamp + validUntilOffset;

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
// // ModifiSub param: Modifying all parameters
// /////////////////////////////////////////////////////////////////////////

    function check_testFuzzModifySubscription(uint256 amount, uint256 interval, uint256 validUntilOffset) public {
        uint256 initialAmount = 10 ether;
        uint256 initialInterval = 30 days;
        uint256 initialValidUntil = block.timestamp + 60 days;

        address owner = subExecutor.getOwner();
        vm.startPrank(owner);
        subExecutor.createSubscription(address(initiator), initialAmount, initialInterval, initialValidUntil, address(token));

        uint256 amount = svm.createUint256("amount");
        uint256 newinterval = svm.createUint256("newinterval");
        uint256 validUntilOffset = svm.createUint256("validUntilOffset");

        vm.assume (1 ether <= amount && amount <= 1000 ether);
        vm.assume (1 days <= newinterval && newinterval <= 365 days);
        vm.assume (1 days <= validUntilOffset && validUntilOffset <= 365 days);

        uint256 validUntil = block.timestamp + validUntilOffset;

        subExecutor.modifySubscription(address(initiator), amount, interval, validUntil, address(token));
        vm.stopPrank();

        SubStorage memory sub = subExecutor.getSubscription(address(initiator));
        assertTrue(sub.amount == amount && sub.paymentInterval == interval && sub.validUntil == validUntil);
    }


// /////////////////////////////////////////////////////////////////////////
// // RevokeSubscription and time
// /////////////////////////////////////////////////////////////////////////

    function check_testFuzzRevokeSubscription(uint256 amount, uint256 interval, uint256 validUntilOffset) public {

        uint256 amount = svm.createUint256("amount");
        uint256 interval = svm.createUint256("interval");
        uint256 validUntilOffset = svm.createUint256("validUntilOffset");

        vm.assume (1 ether <= amount && amount <= 1000 ether);
        vm.assume (1 days <= interval && interval <= 365 days);
        vm.assume (1 days <= validUntilOffset && validUntilOffset <= 365 days);

        uint256 validUntil = block.timestamp + validUntilOffset;

        vm.assume(amount > 0 && interval > 0 && validUntil > block.timestamp);
        address owner = subExecutor.getOwner();
        vm.startPrank(owner);

        subExecutor.createSubscription(address(initiator), amount, interval, validUntil, address(token));

        subExecutor.revokeSubscription(address(initiator));
        vm.stopPrank();

        SubStorage memory sub = subExecutor.getSubscription(address(initiator));
        assert(sub.initiator == address(0));
    }

// /////////////////////////////////////////////////////////////////////////
// // RevokeSubscription in time / vm.assume(revokeTime < block.timestamp)
// /////////////////////////////////////////////////////////////////////////

    function check_testFuzzRevokeSubscriptionWithTime(uint256 amount, uint256 interval, uint256 validUntilOffset, uint256 revokeTimeOffset) public {

        uint256 amount = svm.createUint256("amount");
        uint256 interval = svm.createUint256("interval");
        uint256 validUntilOffset = svm.createUint256("validUntilOffset");
        uint256 revokeTimeOffset = svm.createUint256("revokeTimeOffset");

        vm.assume (1 ether <= amount && amount <= 1000 ether);
        vm.assume (1 days <= interval && interval <= 365 days);
        vm.assume (1 days <= validUntilOffset && validUntilOffset <= 365 days);
        vm.assume (1 days <= revokeTimeOffset && revokeTimeOffset <= 365 days);

        uint256 validUntil = block.timestamp + validUntilOffset;
        uint256 revokeTime = block.timestamp - revokeTimeOffset;
        vm.assume(revokeTime < block.timestamp);

        vm.assume(amount > 0 && interval > 0 && validUntil > block.timestamp);
        address owner = subExecutor.getOwner();
        vm.startPrank(owner);

        subExecutor.createSubscription(address(initiator), amount, interval, validUntil, address(token));

        vm.warp(revokeTime);
        subExecutor.revokeSubscription(address(initiator));

        SubStorage memory sub = subExecutor.getSubscription(address(initiator));
        assertEq(sub.initiator, address(0));
    }


// /////////////////////////////////////////////////////////////////////////
// // Balance
// /////////////////////////////////////////////////////////////////////////

    function check_test_FuzzERC20Payment(uint256 tokenBalance, uint256 paymentAmount) public {

        uint256 supp = 100 ether;
        vm.startPrank(deployer);
        token.mint(deployer, supp);
        token.approve(address(subExecutor), supp);
        vm.stopPrank();

        address owner = subExecutor.getOwner();
        vm.startPrank(owner);       
        subExecutor.createSubscription(address(initiator), paymentAmount, 30 days, block.timestamp + 90 days, address(token));
        vm.stopPrank();

        vm.assume(paymentAmount <= tokenBalance && paymentAmount > 0);

        subExecutor.processPayment();

        uint256 newTokenBalance = token.balanceOf(address(subExecutor));
        assertEq(newTokenBalance, tokenBalance - paymentAmount);
    }

// /////////////////////////////////////////////////////////////////////////
// // 6. _processERC20Payment Logic Flaw: Incorrect Token Transfer
// /////////////////////////////////////////////////////////////////////////

function check_test_initiatePayment(uint256 tokenBalance, uint256 paymentAmount) public {
    vm.assume(tokenBalance >= 1 ether && tokenBalance <= 1000 ether);
    vm.assume(paymentAmount >= 1 wei && paymentAmount <= tokenBalance);

    vm.startPrank(deployer);
    token.mint(address(subExecutor), tokenBalance);
    vm.stopPrank();

    vm.startPrank(address(subExecutor));
    token.approve(address(initiator), tokenBalance);
    vm.stopPrank();

    uint256 subExecutorBalanceBefore = token.balanceOf(address(subExecutor));
    uint256 initiatorBalanceBefore = token.balanceOf(address(initiator));

    address owner = subExecutor.getOwner();
    uint256 validAfter = block.timestamp;
    uint256 validUntil = block.timestamp + 90 days;

    vm.startPrank(owner);
    subExecutor.createSubscription(address(initiator), paymentAmount, 30 days, validUntil, address(token));
    vm.stopPrank();

    vm.warp(validAfter + 30 days + 1);

    // Procesa el pago como el Initiator.
    vm.prank(address(initiator));
    subExecutor.processPayment();

    // Verifica los balances después del pago.
    uint256 subExecutorBalanceAfter = token.balanceOf(address(subExecutor));
    uint256 initiatorBalanceAfter = token.balanceOf(address(initiator));

    // Aserciones para verificar la transferencia correcta de tokens.
    assertEq(subExecutorBalanceAfter, subExecutorBalanceBefore - paymentAmount, "SubExecutor's balance should decrease by the payment amount.");
    assertEq(initiatorBalanceAfter, initiatorBalanceBefore + paymentAmount, "Initiator's balance should increase by the payment amount.");
}


// /////////////////////////////////////////////////////////////////////////
// // 6.2 _processERC20Payment Logic Flaw: Incorrect Token Transfer (uint256 paymentIntervalDays)
// /////////////////////////////////////////////////////////////////////////

function ckeck_Fuzz_processPayment(uint256 tokenBalance, uint256 paymentAmount, uint256 paymentIntervalDays) public {
    // Asegura valores de entrada razonables para el balance de tokens, cantidad de pago, e intervalo de pago.
    vm.assume(tokenBalance >= 1 ether && tokenBalance <= 1000 ether);
    vm.assume(paymentAmount >= 1 wei && paymentAmount <= tokenBalance);
    vm.assume(paymentIntervalDays >= 1 && paymentIntervalDays <= 365); // Intervalo de pago de 1 día a 365 días.

    // Mint tokens al SubExecutor y establece el allowance para el Initiator.
    vm.startPrank(deployer);
    token.mint(address(subExecutor), tokenBalance);
    vm.stopPrank();

    // SubExecutor aprueba al Initiator para gastar tokens en su nombre.
    vm.startPrank(address(subExecutor));
    token.approve(address(initiator), tokenBalance);
    vm.stopPrank();

    // Guarda los balances iniciales del SubExecutor e Initiator para comparar más tarde.
    uint256 subExecutorBalanceBefore = token.balanceOf(address(subExecutor));
    uint256 initiatorBalanceBefore = token.balanceOf(address(initiator));

    // Configura una suscripción en SubExecutor para el Initiator.
    address owner = subExecutor.getOwner();
    uint256 validAfter = block.timestamp;
    uint256 validUntil = block.timestamp + 90 days; // Este valor también podría ser dinámico si lo deseas.

    vm.startPrank(owner);
    subExecutor.createSubscription(address(initiator), paymentAmount, paymentIntervalDays * 1 days, validUntil, address(token));
    vm.stopPrank();

    // Avanza el tiempo para cumplir con el intervalo de pago.
    vm.warp(validAfter + paymentIntervalDays * 1 days + 1);

    // Procesa el pago como el Initiator.
    vm.prank(address(initiator));
    subExecutor.processPayment();

    // Verifica los balances después del pago.
    uint256 subExecutorBalanceAfter = token.balanceOf(address(subExecutor));
    uint256 initiatorBalanceAfter = token.balanceOf(address(initiator));

    // Aserciones para verificar la transferencia correcta de tokens.
    assertEq(subExecutorBalanceAfter, subExecutorBalanceBefore - paymentAmount, "SubExecutor's balance should decrease by the payment amount.");
    assertEq(initiatorBalanceAfter, initiatorBalanceBefore + paymentAmount, "Initiator's balance should increase by the payment amount.");
}


}