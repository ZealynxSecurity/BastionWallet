// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../SeUpH.sol";


contract Halmos_Invariant_InitiatorTest is SetUpHalmosInitiatorTest {



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
        vm.prank(caller);
        (bool success,) = address(initiator).call(gen_calldata(selector));
        vm.assume(success);

        // Verificaciones
        uint256 ownerTokenBalanceAfter = token.balanceOf(deployer);
        uint256 contractTokenBalanceAfter = token.balanceOf(address(initiator));
        console.log("initialOwnerBalanceA",ownerTokenBalanceAfter);
        console.log("InitiatorB",contractTokenBalanceAfter);

        assertEq(ownerTokenBalanceAfter, ownerTokenBalanceBefore + tokenAmount, "Owner token balance incorrect after withdrawal");
        assertEq(contractTokenBalanceAfter, contractTokenBalanceBefore - tokenAmount, "Contract token balance incorrect after withdrawal");
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


