// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./EchidnaConfig.sol";
import "../MockERC20.sol";

contract EchidnaSetup is EchidnaConfig {
    MockERC20 public token;
    address public _erc20Token;

    constructor() {
        token = new MockERC20("Test Token", "TT");
        token.mint(USER1, INITIAL_BALANCE);
        token.mint(USER2, INITIAL_BALANCE);
        token.mint(USER3, INITIAL_BALANCE);
        _erc20Token = address(token);
    }
}