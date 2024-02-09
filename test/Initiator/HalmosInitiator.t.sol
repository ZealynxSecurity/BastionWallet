// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import {SymTest} from "halmos-cheatcodes/SymTest.sol";
import "../../src/subscriptions/Initiator.sol";
import "../../src/MockERC20.sol";
import "../../src/subscriptions/SubExecutor.sol";



contract HalmosInitiatorTest is SymTest, Test {
    Initiator initiator;
    SubExecutor subExecutor;

    MockERC20 public token;

    address public deployer;

    address[] public holders;


    function setUp() public {
        deployer = svm.createAddress("deployer");
        vm.startPrank(deployer);
        
        initiator = new Initiator();
        token = new MockERC20("Test Token", "TT");
        subExecutor = new SubExecutor();

        uint256 supp = svm.createUint256("supp");
        token.mint(deployer, supp);

        vm.stopPrank();


        holders = new address[](3);
        holders[0] = address(0x1001);
        holders[1] = address(0x1002);
        holders[2] = address(0x1003);

        for (uint i = 0; i < holders.length; i++) {
            address account = holders[i];
            uint256 balance = svm.createUint256('balance');
            vm.prank(deployer);
            token.transfer(account, balance);
            for (uint j = 0; j < i; j++) {
                address other = holders[j];
                uint256 amount = svm.createUint256('amount');
                vm.prank(account);
                token.approve(other, amount);
            }
        }
    }


/////////////////////////////////////////////////////////////////////////

// FUZZ TEST

/////////////////////////////////////////////////////////////////////////

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
// registerSubscription > 1
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
// removeSubscription
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
/////////////////////////////////////////////////////////////////////////
    function check_test_Address0_failTokenFalse(
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
// Nunca se llama a _processNativePayment a no ser que sea address(0)
/////////////////////////////////////////////////////////////////////////
    function check_test_initiatePayment(
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

        uint256 warpToTime = block.timestamp + 1 days;
        vm.assume(warpToTime > block.timestamp && warpToTime < validUntil);
        vm.warp(warpToTime);
// vm.warp(svm.createUint(64, "timestamp2"))
        initiator.setSubExecutor(address(subExecutor));

        // Intentar iniciar un pago (no debería fallar)
        vm.prank(subscriber);
        bool success;
        try initiator.initiatePayment(subscriber) {
            success = true;
        } catch {
            success = false;
        }
        assert(success == true);
    }

/////////////////////////////////////////////////////////////////////////
// Nunca se llama a _processNativePayment a no ser que sea address(0)
/////////////////////////////////////////////////////////////////////////

    function check_test_payment_validity_period(uint256 _amount, uint256 _paymentInterval) public {
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

// INVARIANT TEST 

/////////////////////////////////////////////////////////////////////////

//inflation_remainder_within_cap()

    // function _check_invariant_Foo(bytes4[] memory selectors, bytes[] memory data) public {
    //     for (uint i = 0; i < selectors.length; i++) {
    //         (bool success,) = address(token).call(abi.encodePacked(selectors[i], data[i]));
    //         vm.assume(success);
    //         assert(IERCOLAS(token).inflationRemainder() <= IERCOLAS(token).tenYearSupplyCap() - IERCOLAS(token).totalSupply());

    //     }
    // }


/////////////////////////////////////////////////////////////////////////
// Global - Balance
/////////////////////////////////////////////////////////////////////////

    function check_globalInvariants(bytes4 selector, address caller) public {
        // Execute an arbitrary tx
        bytes memory args = svm.createBytes(1024, 'data');
        vm.prank(caller);
       (bool success,) = address(token).call(abi.encodePacked(selector, args));
        vm.assume(success); // ignore reverting cases

        // Record post-state
        assert(token.totalSupply() == address(token).balance);
    }

/////////////////////////////////////////////////////////////////////////
// Global - Balance
/////////////////////////////////////////////////////////////////////////

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

/////////////////////////////////////////////////////////////////////////
// Global
/////////////////////////////////////////////////////////////////////////

    function check_Invariant_globalInvariants(bytes4 selector, address caller) public {
        // Execute an arbitrary tx
        vm.prank(caller);
        (bool success,) = address(initiator).call(gen_calldata(selector));
        vm.assume(success); // ignore reverting cases

        // Record post-state
        // assert(token.totalSupply() == address(token).balance);
    }

/////////////////////////////////////////////////////////////////////////
// withdrawERC20
/////////////////////////////////////////////////////////////////////////

    function check_testInvariant_WithdrawERC20(bytes4 selector, address caller) public {
        // Configuración: Enviar tokens ERC20 al contrato

        uint initialOwnerBalanceA = address(deployer).balance;
        uint InitiatorB = address(initiator).balance;
        // console.log("initialOwnerBalanceA",initialOwnerBalanceA);
        // console.log("InitiatorB",InitiatorB);

        uint256 tokenAmount = 10 ether;
        vm.prank(deployer);
        token.transfer(address(initiator), tokenAmount);

        // Balance de tokens del propietario y del contrato antes de la retirada
        uint256 ownerTokenBalanceBefore = token.balanceOf(deployer);
        uint256 contractTokenBalanceBefore = token.balanceOf(address(initiator));
        // console.log("initialOwnerBalanceA",ownerTokenBalanceBefore);
        // console.log("InitiatorB",contractTokenBalanceBefore);

        // Retirar tokens ERC20 como propietario
        vm.prank(caller);
        (bool success,) = address(initiator).call(gen_calldata(selector));
        vm.assume(success);

        // Verificaciones
        uint256 ownerTokenBalanceAfter = token.balanceOf(deployer);
        uint256 contractTokenBalanceAfter = token.balanceOf(address(initiator));
        // console.log("initialOwnerBalanceA",ownerTokenBalanceAfter);
        // console.log("InitiatorB",contractTokenBalanceAfter);

        // assertEq(ownerTokenBalanceAfter, ownerTokenBalanceBefore + tokenAmount, "Owner token balance incorrect after withdrawal");
        // assertEq(contractTokenBalanceAfter, contractTokenBalanceBefore - tokenAmount, "Contract token balance incorrect after withdrawal");
    }

/////////////////////////////////////////////////////////////////////////

// HANDLER

/////////////////////////////////////////////////////////////////////////
   
    function gen_calldata(bytes4 selector) internal returns (bytes memory) {
        // Ignore view functions
        // Skip for now

        // Create symbolic values to be included in calldata
        address guy = svm.createAddress("guy");
        address src = svm.createAddress("src");
        address dst = svm.createAddress("dst");
        uint256 wad = svm.createUint256("wad");
        uint256 val = svm.createUint256("val");
        uint256 pay = svm.createUint256("pay");

        // Generate calldata based on the function selector
        bytes memory args;
        if (selector == initiator.registerSubscription.selector) {
            args = abi.encode(guy,wad,val,pay,token);
        } else if (selector == initiator.removeSubscription.selector) {
            args = abi.encode(guy);
        } else if (selector == initiator.getSubscription.selector) {
            args = abi.encode(guy);
        } else if (selector == initiator.initiatePayment.selector) {
            args = abi.encode(guy);
        } else if (selector == initiator.withdrawETH.selector) {
            args = abi.encode();
        } else if (selector == initiator.withdrawERC20.selector) {
            args = abi.encode(token);
        
        } else {
            // For functions where all parameters are static (not dynamic arrays or bytes),
            // a raw byte array is sufficient instead of explicitly specifying each argument.
            args = svm.createBytes(1024, "data"); // choose a size that is large enough to cover all parameters
        }
        return abi.encodePacked(selector, args);
    }

}