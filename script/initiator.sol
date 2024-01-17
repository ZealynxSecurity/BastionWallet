// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console2} from "forge-std/Script.sol";
import {EchidnaInitiator} from "../src/echidna/EchidnaInitiator.sol";


contract initiator is Script {
    EchidnaInitiator public echidnaInitiator;
    // veOLAS public veolas;


    function run() public {
        echidnaInitiator = new EchidnaInitiator();


        console2.log( "initiator", address(echidnaInitiator));
   
   
    }
}

//address => 0x5615dEB798BB3E4dFa0139dFa1b3D433Cc23b72f