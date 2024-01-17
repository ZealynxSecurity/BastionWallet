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

        // Intentar registrar la misma suscripción de nuevo
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
    uint256 validUntil = block.timestamp + 30 days;
    uint256 paymentInterval = 10 days;

    // Registrar la suscripción como el suscriptor
    vm.prank(subscriber);
    initiator.registerSubscription(subscriber, amount, validUntil, paymentInterval, address(token));

    // Asegurarse de que estamos en un momento en el que la suscripción está activa y no ha expirado
    vm.warp(block.timestamp + 1 days);

    // Intentar iniciar un pago (no debería fallar)
    initiator.initiatePayment(subscriber);
    
    // Verificaciones adicionales pueden ser añadidas aquí si es necesario
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

// INVARIANT TEST 




}