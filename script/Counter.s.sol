// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console2} from "forge-std/Script.sol";
import {Initiator} from "../src/subscriptions/Initiator.sol";


contract initiator is Script {
    Initiator public initiator;
    // veOLAS public veolas;


    function run() public {
        initiator = new Initiator();


        console2.log( "initiator", address(initiator));
   
   
    }
}

//address => 0x5615dEB798BB3E4dFa0139dFa1b3D433Cc23b72f