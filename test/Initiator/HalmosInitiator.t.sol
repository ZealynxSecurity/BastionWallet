// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import {SymTest} from "halmos-cheatcodes/SymTest.sol";
import "../../src/subscriptions/Initiator.sol";
import "../../src/MockERC20.sol";

// import "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";



contract HalmosInitiatorTest is SymTest, Test {
    Initiator initiator;
    MockERC20 public token;

    address public deployer;

    address[] public holders;


    function setUp() public {
        deployer = svm.createAddress("deployer");
        vm.startPrank(deployer);
        
        initiator = new Initiator();
        token = new MockERC20("Test Token", "TT");

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