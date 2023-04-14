// example modified from the smartian paper

pragma solidity 0.7.6;

contract cstatereq {
    // State variables in the storage.
    address owner = address(0);
    uint256 private stateA = 0;
    uint256 private stateB = 0;
    uint256 CONST = 32;

    function C() public {
        // Constructor
        owner = msg.sender;
    }

    function f(uint256 x) public {
        require(msg.sender == owner);
        stateA = x;
    }

    function g(uint256 y) public {
        require(stateA % CONST == 1);
        stateB = y - 10;
    }

    function h() public {
        require(stateB == 62);
        selfdestruct(payable(msg.sender));
    }
}
