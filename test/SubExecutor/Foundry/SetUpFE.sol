// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../../../src/subscriptions/SubExecutor.sol";
import "../../../src/subscriptions/Initiator.sol";
import "../../../src/MockERC20.sol";

// import "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

contract SetUp_FoundrySubExecutor is Test {
    Initiator initiator;
    SubExecutor subExecutor;
    MockERC20 public token;

    address public deployer;
    address[] public holders;


    function setUp() public {

        deployer = makeAddr("deployer");
        vm.startPrank(deployer);
        
        initiator = new Initiator();
        subExecutor = new SubExecutor();
        token = new MockERC20("Test Token", "TT");

        uint256 supp = 100 ether;
        token.mint(deployer, supp);
        token.approve(address(token), supp);

        vm.stopPrank();

        holders = new address[](3);
        holders[0] = address(0x1001);
        holders[1] = address(0x1002);
        holders[2] = address(0x1003);

        for (uint i = 0; i < holders.length; i++) {
            address account = holders[i];
            uint256 balance = 10 ether;
            vm.prank(deployer);
            token.transfer(account, balance);
            for (uint j = 0; j < i; j++) {
                address other = holders[j];
                uint256 amount = 5 ether;
                vm.prank(account);
                token.approve(other, amount);
            }
        }
    }

}