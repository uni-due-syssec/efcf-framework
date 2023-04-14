pragma solidity ^0.8.0;

contract Overflow {
    function f(uint256 x) public {
        type(uint256).max + x;
    }
}
