/*

  << TestERC20 >>

*/

pragma solidity >=0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract TestERC20 is ERC20 {
    /**
     */
    constructor() ERC20("test", "TSTADS") {}

    /**
     */
    function mint(address to, uint256 value) public returns (bool) {
        _mint(to, value);
        return true;
    }
}
