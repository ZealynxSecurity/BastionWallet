// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../../src/subscriptions/SubExecutor.sol";
import "../../src/subscriptions/Initiator.sol";
import "../../src/MockERC20.sol";

// import "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

contract SFoundrySubExecutorTest is Test {
    Initiator initiator;
    SubExecutor subExecutor;
    MockERC20 public token;

    address public deployer;

    address[] public holders;


    function setUp() public {

        deployer = makeAddr("deployer");
        vm.startPrank(deployer);
        
        initiator = new Initiator();
        subExecutor = new SubExecutor();
        token = new MockERC20("Test Token", "TT");

        uint256 supp = 100 ether;
        token.mint(deployer, supp);
        token.approve(address(token), supp);

        vm.stopPrank();

        holders = new address[](3);
        holders[0] = address(0x1001);
        holders[1] = address(0x1002);
        holders[2] = address(0x1003);

        for (uint i = 0; i < holders.length; i++) {
            address account = holders[i];
            uint256 balance = 10 ether;
            vm.prank(deployer);
            token.transfer(account, balance);
            for (uint j = 0; j < i; j++) {
                address other = holders[j];
                uint256 amount = 5 ether;
                vm.prank(account);
                token.approve(other, amount);
            }
        }
    }


/////////////////////////////////////////////////////////////////////////

// UNIT TEST

/////////////////////////////////////////////////////////////////////////


    // function testFuzzModifySub(uint256 amount, uint256 newAmount, uint256 newValidUntil) public {

    //     // Registrar sub
    //     vm.assume(amount < MAX_UINT256); 
    //     // subExecutor.createSubscription(initiator, amount /*other params*/);

    //     // Fuzzear modificación  
    //     vm.assume(newAmount < MAX_UINT256);
    //     vm.assume(newValidUntil < MAX_UINT256);

    //     // try subExecutor.modifySubscription(
    //     //     initiator,
    //     //     newAmount,
    //     //     newValidUntil /*other params*/
    //     // ) {
    //     //     assertTrue(true);
    //     // } catch (error) {
    //     //     emit log("Modify failed");  
    //     // }

    //     // Verificar storage actualizado
    //     // SubStorage storage updated = subExecutor.getSubscription(initiator);
        
    //     assertEq(updated.amount, newAmount);
    //     assertEq(updated.validUntil, newValidUntil);
    // }



    // function testFrontrunRevoke() public {

        
    //     address attacker = address(1337);

    //     // Registrar sub
    //     vm.prank(holders[0]);
    //     subExecutor.createSubscription();

    //     // Revocar como attacker
    //     vm.prank(attacker);
    //     subExecutor.revokeSubscription(address(initiator));

    //     // Attempt payment (debería fallar)
    //     vm.prank(holders[0]);
    //     vm.expectRevert("Subscription not found");
    //     subExecutor.processPayment();

    // }


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
    assertEq(sub.amount, amount);
    assertEq(sub.paymentInterval, interval);
    assertEq(sub.validUntil, validUntil);
    assertEq(sub.erc20Token, erc20Token);
}



/////////////////////////////////////////////////////////////////////////

// FUZZ TEST

/////////////////////////////////////////////////////////////////////////


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
// // Valor block.timestamp -1 => validUntil = 0
// /////////////////////////////////////////////////////////////////////////
    function testFuzzSubscriptionNegative() public {
        uint256 amount = 1 ether;
        uint256 interval = 30 days;
        uint256 validUntil = block.timestamp -1 ; // Fecha muy lejana en el futuro

        console.log("Valor", validUntil);

        // vm.assume(validUntil > block.timestamp);
        address owner = subExecutor.getOwner();
        vm.startPrank(owner);
        subExecutor.createSubscription(address(initiator), amount, interval, validUntil, address(token));

        // Verificar que la suscripción se haya creado correctamente con fechas extremas
        SubStorage memory sub = subExecutor.getSubscription(address(initiator));
        uint256 valid = sub.validUntil;
        console.log("Valor", valid);
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
// // ModifiSub param: todos
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
// // RevokeSubscription and time
// /////////////////////////////////////////////////////////////////////////

function testFuzzRevokeSubscription() public {

    // Configurar una suscripción
    address owner = subExecutor.getOwner();
    vm.startPrank(owner);
    subExecutor.createSubscription(address(initiator), 1 ether, 30 days, block.timestamp + 90 days, address(token));

    // Revocar la suscripción
    subExecutor.revokeSubscription(address(initiator));

    // Verificar que la suscripción haya sido revocada
    SubStorage memory sub = subExecutor.getSubscription(address(initiator));
    assertEq(sub.initiator, address(0)); // O alguna otra verificación de que la suscripción fue revocada
}


// function testFuzzRevokeSubscriptionWithTime(address initiator, uint256 validUntilOffset, uint256 revokeTimeOffset) public {
//     // Configuración inicial
//     uint256 amount = 1 ether;
//     uint256 interval = 30 days;
//     uint256 validUntil = block.timestamp + bound(validUntilOffset, 1 days, 365 days);

//     vm.assume(initiator != address(0) && validUntil > block.timestamp);
//     subExecutor.createSubscription(initiator, amount, interval, validUntil, address(mockERC20));

//     // Avanzar el tiempo y revocar la suscripción
//     uint256 revokeTime = block.timestamp + bound(revokeTimeOffset, 1 days, 365 days);
//     vm.warp(revokeTime);
//     subExecutor.revokeSubscription(initiator);

//     // Verificar que la suscripción se haya revocado correctamente
//     SubStorage memory sub = subExecutor.getSubscription(initiator);
//     assertEq(sub.initiator, address(0));
// }


// /////////////////////////////////////////////////////////////////////////
// // Balance
// /////////////////////////////////////////////////////////////////////////

//     // function testFuzzBalances(
//     //     uint256 amount,
//     //     address token  
//     //     ) public {

//     //     vm.assume(amount < MAX_UINT);  

//     //     if (token == address(0)) {
//     //         vm.deal(address(subExecutor), amount);
//     //     } else {
//     //         vm.assume(ERC20(token).totalSupply() >= amount); 
//     //     vm.prank(token);
//     //         ERC20(token).transfer(address(subExecutor), amount);    
//     //     }

//     //     try subExecutor.processPayment(msg.sender) {
//     //         assertTrue(true);
//     //     } catch Error(string memory reason) {
//     //         if (token == address(0)) {
//     //         assertEq(reason, "Insufficient Ether balance"); 
//     //         } else {
//     //         assertEq(reason, "Insufficient token balance");   
//     //         }
//     //         emit log("Balance check failed");    
//     //     }  

//     // }


    function test_FuzzERC20Payment(uint256 tokenBalance, uint256 paymentAmount) public {
        // Configurar el balance del token ERC20 en el contrato
         uint256 supp = 100 ether;
        vm.startPrank(deployer);
        token.mint(deployer, supp);
        token.approve(address(subExecutor), supp);
        vm.stopPrank();
        vm.assume (1 ether <= tokenBalance && tokenBalance <= 1000 ether);

        // Configurar una suscripción con token ERC20
         address owner = subExecutor.getOwner();
        vm.startPrank(owner);       
        subExecutor.createSubscription(address(initiator), paymentAmount, 30 days, block.timestamp + 90 days, address(token));
        vm.stopPrank();

        vm.assume(paymentAmount <= tokenBalance && paymentAmount > 0);

        // Intentar procesar el pago
        subExecutor.processPayment();

        // Verificar que el pago se haya realizado correctamente
        uint256 newTokenBalance = token.balanceOf(address(subExecutor));
        assertEq(newTokenBalance, tokenBalance - paymentAmount);
    }


// /////////////////////////////////////////////////////////////////////////
// // Token ERC20 -  Diferentes Montos de Pago y Balances ERC20
// /////////////////////////////////////////////////////////////////////////

//     // function testFuzzERC20Tokens(address token) public {

//     //     if (token == address(0)) {
//     //         vm.deal(address(this), 1 ether);
//     //     } else {
//     //         vm.startPrank(token);
//     //         ERC20 alienToken = ERC20(token); 
//     //         alienToken.mint(address(this), 10000);
//     //         vm.stopPrank();
//     //     }

//     //     try subExecutor.createSubscription(
//     //         initiator, 
//     //         10,
//     //         block.timestamp + 365 days,
//     //         30 days, 
//     //         token
//     //     ) {  
//     //         assertTrue(true);
//     //     } catch (error) {
//     //         if (token == address(0)) {
//     //         assertFalse(true); // No debería fallar con ETH
//     //         } else {
//     //         assertEq(error, "Invalid token"); // Token no válido
//     //         }
//     //     }

//     // }

// function testFuzzERC20PaymentWithVariableAmounts(uint256 tokenBalance, uint256 paymentAmount) public {
//     // Configurar un balance de token ERC20
//     uint256 mintAmount = bound(tokenBalance, 1 ether, 1000 ether);
//     mockERC20.mint(address(subExecutor), mintAmount);

//     // Configurar una suscripción
//     uint256 subscriptionAmount = bound(paymentAmount, 1 ether, mintAmount);
//     subExecutor.createSubscription(address(initiator), subscriptionAmount, 30 days, block.timestamp + 90 days, address(mockERC20));

//     vm.assume(subscriptionAmount <= mintAmount);

//     // Procesar el pago y verificar el resultado
//     subExecutor.processPayment();
//     uint256 newTokenBalance = mockERC20.balanceOf(address(subExecutor));
//     assertEq(newTokenBalance, mintAmount - subscriptionAmount);
// }

// /////////////////////////////////////////////////////////////////////////
// // Payment
// /////////////////////////////////////////////////////////////////////////

//     function testFuzzPayment(uint256 balance, uint256 paymentAmount) public {
//         // Configurar un balance en el contrato
//         vm.deal(address(subExecutor), balance);

//         // Configuración inicial de la suscripción
//         subExecutor.createSubscription(address(initiator), paymentAmount, 30 days, block.timestamp + 90 days, address(0));

//         // Asegurarse de que los montos sean manejables
//         vm.assume(paymentAmount <= balance && paymentAmount > 0);

//         // Intentar procesar el pago
//         subExecutor.processPayment();
        
//         // Verificar resultados
//         uint256 newBalance = address(subExecutor).balance;
//         assertEq(newBalance, balance - paymentAmount);
//     }

//     function testFuzzPaymentInterval(uint256 initialTimestampOffset, uint256 paymentInterval, uint256 warpTime) public {
//         uint256 amount = 1 ether;
//         uint256 validUntil = block.timestamp + 365 days;
//         address erc20Token = address(mockERC20);

//         // Asegurarse de que los intervalos y tiempos sean razonables
//         paymentInterval = bound(paymentInterval, 1 hours, 365 days);
//         warpTime = bound(warpTime, 1 hours, 2 * 365 days);
//         vm.assume(paymentInterval < warpTime);

//         // Crear una suscripción y avanzar el tiempo
//         subExecutor.createSubscription(address(initiator), amount, paymentInterval, validUntil, erc20Token);
//         vm.warp(block.timestamp + initialTimestampOffset + warpTime);

//         // Intentar procesar el pago
//         bool shouldRevert = block.timestamp < validUntil && (block.timestamp + warpTime) < (initialTimestampOffset + paymentInterval);
//         if (shouldRevert) {
//             vm.expectRevert("Payment interval not yet reached");
//         }
//         subExecutor.processPayment();

//         // Verificaciones adicionales si es necesario
//     }


// /////////////////////////////////////////////////////////////////////////
// // Subscription Dates
// /////////////////////////////////////////////////////////////////////////

// function testFuzzSubscriptionDates(uint256 validUntilOffset, uint256 paymentInterval) public {
//     uint256 validUntil = block.timestamp + bound(validUntilOffset, 1 days, 3650 days);
//     paymentInterval = bound(paymentInterval, 1 days, 365 days);

//     vm.assume(validUntil > block.timestamp && paymentInterval > 0);

//     subExecutor.createSubscription(address(initiator), 1 ether, paymentInterval, validUntil, address(mockERC20));

//     // Verificar que las fechas se hayan establecido correctamente
//     SubStorage memory sub = subExecutor.getSubscription(address(initiator));
//     assertEq(sub.validUntil, validUntil);
//     assertEq(sub.paymentInterval, paymentInterval);
// }

// /////////////////////////////////////////////////////////////////////////
// // Access Control
// /////////////////////////////////////////////////////////////////////////

// function testFuzzAccessControlDifferentRoles(address caller, bool isOwnerOrEntryPoint) public {
//     vm.assume(caller != address(0));

//     if (isOwnerOrEntryPoint) {
//         // Simular que el llamante es el propietario o el punto de entrada
//         vm.prank(getKernelStorage().owner);
//         subExecutor.createSubscription(address(initiator), 1 ether, 30 days, block.timestamp + 90 days, address(mockERC20));
//     } else {
//         // Simular que el llamante no es el propietario o el punto de entrada
//         vm.prank(caller);
//         vm.expectRevert("account: not from entrypoint or owner or self");
//         subExecutor.createSubscription(address(initiator), 1 ether, 30 days, block.timestamp + 90 days, address(mockERC20));
//     }
// }



}
