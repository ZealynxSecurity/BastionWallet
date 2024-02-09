// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./EchidnaConfig.sol";
import "../MockERC20.sol";

contract EchidnaSetup is EchidnaConfig {
    MockERC20 public token;
    address internal _erc20Token;

    constructor() {
        token = new MockERC20("Test Token", "TT");
        _erc20Token = address(token);
    }
}