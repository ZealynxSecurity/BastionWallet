// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import {SymTest} from "halmos-cheatcodes/SymTest.sol";
import "../../../src/subscriptions/Initiator.sol";
import "../../../src/MockERC20.sol";
import "../../../src/subscriptions/SubExecutor.sol";



contract SetUpHalmosInitiatorTest is SymTest, Test {
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

}