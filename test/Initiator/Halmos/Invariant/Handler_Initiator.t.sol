// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../SeUpH.sol";


contract Halmos_Invariant_InitiatorTest is SetUpHalmosInitiatorTest {


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


