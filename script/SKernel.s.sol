// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script, console2} from "forge-std/Script.sol";
import "../../src/Kernel.sol";
import "account-abstraction/interfaces/IEntryPoint.sol";



contract SKernel is Script {
    Kernel kernel;
    IEntryPoint entryPoint; // Utiliza IEntryPoint en lugar de address

    // event PlayerEncoded(bytes32 indexed a, bytes32 indexed b, bytes32 indexed c);
    event cons(bytes const);

    function run() public {
        // address entryPointAddress = 0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789;
        // entryPoint = IEntryPoint(entryPointAddress); // Convierte la dirección a IEntryPoint
        kernel = new Kernel(entryPoint); // Pasa el IEntryPoint al constructor
        console2.log( "kernel", address(kernel));
        // console2.log( "entryPoint", address(entryPoint));

        bytes memory const = abi.encode(address(0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789));

        emit cons(const);
        // emit PlayerEncoded(randomId1, randomId2, randomId3);
    }
}