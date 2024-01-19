// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../../src/subscriptions/Initiator.sol";
import "../../src/MockERC20.sol";

// import "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

contract FoundryInitiatorTest is Test {
    Initiator initiator;
    MockERC20 public token;

    address public deployer;

    address[] public holders;


    function setUp() public {

        deployer = makeAddr("deployer");
        vm.startPrank(deployer);
        
        initiator = new Initiator();
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


/////////////////////////////////////////////////////////////////////////
// registerSubscription
/////////////////////////////////////////////////////////////////////////

 function test_check_testRegisterSubscription() public { //@audit-ok
        address subscriber = holders[0];
        uint256 amount = 1 ether;
        uint256 validUntil = block.timestamp + 30 days;
        uint256 paymentInterval = 10 days;

        // Registrar la suscripción como el suscriptor
        vm.prank(subscriber);
        initiator.registerSubscription(subscriber, amount, validUntil, paymentInterval, address(token));

        // Verificaciones
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

/////////////////////////////////////////////////////////////////////////
// registerSubscription > 1
/////////////////////////////////////////////////////////////////////////

    function test_failRegisterSubscriptionIfSubscriptionExists() public { //@audit
        address subscriber = holders[0];
        uint256 amount = 1 ether;
        uint256 validUntil = block.timestamp + 30 days;
        uint256 paymentInterval = 10 days;

        // Registrar una suscripción
        vm.prank(subscriber);
        initiator.registerSubscription(subscriber, amount, validUntil, paymentInterval, address(token));

        // Intentar registrar la misma suscripción de nuevo
        vm.expectRevert();
        vm.prank(subscriber);
        initiator.registerSubscription(subscriber, amount, validUntil, paymentInterval, address(token));
    }

/////////////////////////////////////////////////////////////////////////
// registerSubscription NoToken ERC20
/////////////////////////////////////////////////////////////////////////
    function test_failTokenFalse() public { //@audit
        address subscriber = holders[0];
        uint256 amount = 1 ether;
        uint256 validUntil = block.timestamp + 30 days;
        uint256 paymentInterval = 10 days;
        address tokenFalso =  address(this);

        // Registrar una suscripción
        vm.prank(subscriber);
        vm.expectRevert();
        initiator.registerSubscription(subscriber, amount, validUntil, paymentInterval, tokenFalso);

    }

/////////////////////////////////////////////////////////////////////////
// removeSubscription
/////////////////////////////////////////////////////////////////////////

    function test_check_testRemoveSubscription() public { //@audit
        address subscriber = holders[0];
        uint256 amount = 1 ether;
        uint256 validUntil = block.timestamp + 30 days;
        uint256 paymentInterval = 10 days;

        // Registrar y luego eliminar la suscripción como el suscriptor
        vm.prank(subscriber);
        initiator.registerSubscription(subscriber, amount, validUntil, paymentInterval, address(token));
        vm.prank(subscriber);
        initiator.removeSubscription(subscriber);

        // Verificaciones
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


/////////////////////////////////////////////////////////////////////////
// withdrawETH
/////////////////////////////////////////////////////////////////////////


    function test_WithdrawETH() public { //OK
        // Configuración: Enviar ETH al contrato
        uint initialOwnerBalanceA = address(deployer).balance;
        uint InitiatorB = address(initiator).balance;
        console.log("initialOwnerBalanceA",initialOwnerBalanceA);
        console.log("InitiatorB",InitiatorB);
        console.log("===========");

        uint256 amount = 1 ether;
        payable(address(initiator)).transfer(amount);

        // Balance del propietario antes de la retirada
        uint256 ownerBalanceBefore = address(deployer).balance;
        uint256 contractBalanceBefore = address(initiator).balance;
        console.log("initialOwnerBalance",ownerBalanceBefore);
        console.log("InitiatorD",contractBalanceBefore);
        console.log("===========");

        // Retirar ETH como propietario
        vm.prank(deployer);
        initiator.withdrawETH();

        // Verificaciones
        uint256 ownerBalanceAfter = address(deployer).balance;
        uint256 contractBalanceAfter = address(initiator).balance;
        console.log("finalOwnerBalance",ownerBalanceAfter);
        console.log("InitiatorF",contractBalanceAfter);

        assertEq(ownerBalanceAfter, ownerBalanceBefore + amount);
        assertEq(contractBalanceAfter, contractBalanceBefore - amount);
    }

/////////////////////////////////////////////////////////////////////////
// withdrawETH No Owner
/////////////////////////////////////////////////////////////////////////
    function test_TfailWithdrawETHByNonOwner() public { //OK
        // Configuración: Enviar ETH al contrato
        uint256 amount = 1 ether;
        payable(address(initiator)).transfer(amount);

        // Intentar retirar ETH como no propietario
        address nonOwner = holders[0];
        vm.prank(nonOwner);
        vm.expectRevert();
        initiator.withdrawETH(); // Esto debería fallar
}

/////////////////////////////////////////////////////////////////////////
// withdrawERC20
/////////////////////////////////////////////////////////////////////////

function test_check_testWithdrawERC20() public {
    // Configuración: Enviar tokens ERC20 al contrato

    uint initialOwnerBalanceA = address(deployer).balance;
    uint InitiatorB = address(initiator).balance;
    console.log("initialOwnerBalanceA",initialOwnerBalanceA);
    console.log("InitiatorB",InitiatorB);

    uint256 tokenAmount = 10 ether;
    vm.prank(deployer);
    token.transfer(address(initiator), tokenAmount);

    // Balance de tokens del propietario y del contrato antes de la retirada
    uint256 ownerTokenBalanceBefore = token.balanceOf(deployer);
    uint256 contractTokenBalanceBefore = token.balanceOf(address(initiator));
    console.log("initialOwnerBalanceA",ownerTokenBalanceBefore);
    console.log("InitiatorB",contractTokenBalanceBefore);

    // Retirar tokens ERC20 como propietario
    vm.prank(deployer);
    initiator.withdrawERC20(address(token));

    // Verificaciones
    uint256 ownerTokenBalanceAfter = token.balanceOf(deployer);
    uint256 contractTokenBalanceAfter = token.balanceOf(address(initiator));
    console.log("initialOwnerBalanceA",ownerTokenBalanceAfter);
    console.log("InitiatorB",contractTokenBalanceAfter);

    assertEq(ownerTokenBalanceAfter, ownerTokenBalanceBefore + tokenAmount, "Owner token balance incorrect after withdrawal");
    assertEq(contractTokenBalanceAfter, contractTokenBalanceBefore - tokenAmount, "Contract token balance incorrect after withdrawal");
}

/////////////////////////////////////////////////////////////////////////
// withdrawERC20 No Owner
/////////////////////////////////////////////////////////////////////////
function test_check_failWithdrawERC20ByNonOwner() public {
    // Configuración: Enviar tokens ERC20 al contrato
    uint256 tokenAmount = 10 ether;
    vm.prank(deployer);
    token.transfer(address(initiator), tokenAmount);

    // Intentar retirar tokens ERC20 como no propietario
    address nonOwner = holders[0];
    vm.prank(nonOwner);
    vm.expectRevert();
    initiator.withdrawERC20(address(token)); // Esto debería fallar
}

/////////////////////////////////////////////////////////////////////////
// initiatePayment
/////////////////////////////////////////////////////////////////////////


function testFail_initiatePayment_ExpiredSubscription() public {
    address subscriber = holders[0];
    uint256 amount = 1 ether;
    uint256 validUntil = block.timestamp + 30 days;
    uint256 paymentInterval = 10 days;

    // Registrar la suscripción como el suscriptor
    vm.prank(subscriber);
    initiator.registerSubscription(subscriber, amount, validUntil, paymentInterval, address(token));

    // Avanzar el tiempo para que la suscripción expire
    vm.warp(block.timestamp + 31 days);

    // Intentar iniciar un pago (debería fallar debido a que la suscripción expiró)
    vm.expectRevert("Subscription is not active");
    initiator.initiatePayment(subscriber);
}

    function test_initiatePayment_ActiveSubscription() public {
        address subscriber = holders[0];
        uint256 amount = 1 ether;
        uint256 _validAfter = block.timestamp + 1 days;
        uint256 validUntil = _validAfter + 10 days;
        uint256 paymentInterval = 10 days;

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
            success = true;
        } catch {
            success = false;
        }

        assertTrue(success, "La llamada a initiatePayment haber sido exitosa");
    }


/////////////////////////////////////////////////////////////////////////

// FUZZ TEST

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
// Nunca se llama a _processNativePayment a no ser que sea address(0)
/////////////////////////////////////////////////////////////////////////
    function test_Fuzz_tinitiatePayment_ActiveSubscription(        
            uint256 amount,
            uint256 _validUntil,
            uint256 paymentInterval,
            address FalseToken) public {


            address subscriber = holders[0];
            uint256 _validAfter = block.timestamp + 1 days;
            uint256 validUntil = _validAfter + 10 days;

            amount = bound(amount, 1 ether, 1000 ether);
            paymentInterval = bound(paymentInterval, 1 days, 365 days);

            // Registrar la suscripción
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
            // Avanzar al momento en que la suscripción está activa pero no ha expirado
            uint256 warpToTime = _validAfter + 10;
            vm.warp(warpToTime);

            // Intentar iniciar un pago
            vm.prank(subscriber);
            bool success;
            try initiator.initiatePayment(subscriber) {
                success = true;
            } catch {
                success = false;
            }

            assertTrue(success, "La llamada a initiatePayment haber sido exitosa");
        }

/////////////////////////////////////////////////////////////////////////
// Nunca se llama a _processNativePayment a no ser que sea address(0)
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
// registerSubscription > 1
/////////////////////////////////////////////////////////////////////////
    function testFuzzMultipleSubscriptions() public {
        address subscriber = holders[0];
        uint256 iterations = 5; // Número de veces que quieres registrar al suscriptor

        for (uint256 i = 0; i < iterations; i++) {
            // Generar valores aleatorios para cada registro
            uint256 amount = uint256(keccak256(abi.encodePacked(block.timestamp, subscriber, i))) % 100 ether;
            uint256 validUntil = block.timestamp + (1 days + i * 1 days);
            uint256 paymentInterval = (1 days + i * 1 hours);

            // Asegurar que los valores son razonables
            vm.assume(amount > 0);
            vm.assume(validUntil > block.timestamp);
            vm.assume(paymentInterval > 0);

            // Registrar la suscripción
            vm.prank(subscriber);
            initiator.registerSubscription(subscriber, amount, validUntil, paymentInterval, address(token));
            address[] memory registeredSubscribers = initiator.getSubscribers();
            console.log("Subscriber i",registeredSubscribers[i]);
            console.log("===================");
            assertEq(registeredSubscribers[i], subscriber);
        }
    }




}