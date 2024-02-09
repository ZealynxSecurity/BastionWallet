// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../../src/subscriptions/Initiator.sol";

contract PropertiesInitiator {

    function invariant_INITIATOR_01(uint256 balance) internal view returns (bool) {       
        return balance >= 4;
    }
}