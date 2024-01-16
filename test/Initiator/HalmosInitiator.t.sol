// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../../src/subscriptions/Initiator.sol";
import "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
// import {IERC20} from "forge-std/interfaces/IERC20.sol";


import {SymTest} from "halmos-cheatcodes/SymTest.sol";


contract HalmosInitiatorTest is SymTest, Test {
    Initiator initiator;
    ERC20 public token;

    address public deployer;



    function setUp() public {
        // deployer = svm.createAddress("deployer");
        deployer = vm.addr(1);
        vm.prank(deployer);
        initiator = new Initiator();
        token = new ERC20("Test Token", "TT");
    }


// UNIT
 function check_testRegisterSubscription() public {
        address subscriber = address(1);
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

        address[] memory registeredSubscribers = initiator.getSubscribers();
        assertEq(registeredSubscribers[0], subscriber);
    }

    function check_testRemoveSubscription() public {
        address subscriber = address(1);
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
// whithdraw
    function testWithdrawETH() public {
        // Enviar ETH al contrato
        payable(address(initiator)).transfer(1 ether);

        // Balance de ETH antes de la retirada
        uint initialBalance = address(this).balance;

        // Solo el propietario debería poder retirar ETH
        vm.prank(address(initiator.owner()));
        initiator.withdrawETH();

        // Verificar que el balance de ETH se ha incrementado correctamente
        uint finalBalance = address(this).balance;
        assertEq(finalBalance, initialBalance + 1 ether);
    }

    function testFailWithdrawETHByNonOwner() public {
        // Enviar ETH al contrato
        payable(address(initiator)).transfer(1 ether);

        // Intentar retirar ETH como no propietario
        vm.prank(address(0x1234)); // Dirección arbitraria que no es el propietario
        initiator.withdrawETH(); // Esto debería fallar
    }

/////////////////////////////////////////////////////////////////////////

    function testTWithdrawETH() public {
        // Configuración: Enviar ETH al contrato
        uint256 amount = 1 ether;
        payable(address(initiator)).transfer(amount);

        // Balance del propietario antes de la retirada
        uint256 ownerBalanceBefore = address(deployer).balance;
        uint256 contractBalanceBefore = address(initiator).balance;

        // Retirar ETH como propietario
        vm.prank(deployer);
        initiator.withdrawETH();

        // Verificaciones
        uint256 ownerBalanceAfter = address(deployer).balance;
        uint256 contractBalanceAfter = address(initiator).balance;

        assertEq(ownerBalanceAfter, ownerBalanceBefore + amount);
        assertEq(contractBalanceAfter, contractBalanceBefore - amount);
    }

    function test_TfailWithdrawETHByNonOwner() public {
        // Configuración: Enviar ETH al contrato
        uint256 amount = 1 ether;
        payable(address(initiator)).transfer(amount);

        // Intentar retirar ETH como no propietario
        address nonOwner = address(2);
        vm.prank(nonOwner);
        initiator.withdrawETH(); // Esto debería fallar
}

/////////////////////////////////////////////////////////////////////////

function test_check_testWithdrawERC20() public {
    // Configuración: Enviar tokens ERC20 al contrato
    uint256 tokenAmount = 100 ether;
    payable(address(initiator)).transfer(tokenAmount);

    // Balance de tokens del propietario y del contrato antes de la retirada
    uint256 ownerBalanceBefore = address(deployer).balance;
    uint256 contractBalanceBefore = address(initiator).balance;

    console.log("1",ownerBalanceBefore );
    console.log("2",contractBalanceBefore );

    // Retirar tokens ERC20 como propietario
    vm.prank(deployer);
    initiator.withdrawERC20(address(token));

    // Verificaciones
        uint256 ownerBalanceAfter = address(deployer).balance;
        uint256 contractBalanceAfter = address(initiator).balance;

        console.log("1",ownerBalanceAfter );
        console.log("2",contractBalanceAfter );

    assertEq(ownerBalanceAfter, ownerBalanceBefore + tokenAmount);
    assertEq(contractBalanceAfter, contractBalanceBefore - tokenAmount);
}

function test_check_failWithdrawERC20ByNonOwner() public {
    // Configuración: Enviar tokens ERC20 al contrato
    uint256 tokenAmount = 1000 ether;
    payable(address(initiator)).transfer(tokenAmount);

    // Intentar retirar tokens ERC20 como no propietario
    address nonOwner = address(2);
    vm.prank(nonOwner);
    initiator.withdrawERC20(address(token)); // Esto debería fallar
}

/////////////////////////////////////////////////////////////////////////

// FUZZ
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

    function check_testFUZZ_remove(
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

//inflation_remainder_within_cap()

    // function _check_invariant_Foo(bytes4[] memory selectors, bytes[] memory data) public {
    //     for (uint i = 0; i < selectors.length; i++) {
    //         (bool success,) = address(token).call(abi.encodePacked(selectors[i], data[i]));
    //         vm.assume(success);
    //         assert(IERCOLAS(token).inflationRemainder() <= IERCOLAS(token).tenYearSupplyCap() - IERCOLAS(token).totalSupply());

    //     }
    // }

    function check_globalInvariants(bytes4 selector, address caller) public {
        // Execute an arbitrary tx
        bytes memory args = svm.createBytes(1024, 'data');
        vm.prank(caller);
       (bool success,) = address(token).call(abi.encodePacked(selector, args));
        vm.assume(success); // ignore reverting cases

        // Record post-state
        assert(token.totalSupply() == address(token).balance);
    }

    function checkNoBackdoor(bytes4 selector, address caller, address other) public virtual {
        // consider two arbitrary distinct accounts
        // address caller = svm.createAddress("caller");
        // address other = svm.createAddress("other");
        bytes memory args = svm.createBytes(1024, 'data');
        vm.assume(other != caller);

        // record their current balances
        uint256 oldBalanceOther = (token).balanceOf(other);

        uint256 oldAllowance = (token).allowance(other, caller);

        // consider an arbitrary function call to the token from the caller
        vm.prank(caller);
        (bool success,) = address(token).call(abi.encodePacked(selector, args));
        vm.assume(success);

        uint256 newBalanceOther = (token).balanceOf(other);

        // ensure that the caller cannot spend other' tokens without approvals
        if (newBalanceOther < oldBalanceOther) {
            assert(oldAllowance >= oldBalanceOther - newBalanceOther);
        }
    }


}