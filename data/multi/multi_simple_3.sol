pragma solidity ^0.7;

contract multi_simple_3 {
    bool state1 = false;
    bool state2 = false;
    bool state3 = false;

    constructor() payable {}

    function f1() public {
        require(!state1);
        state1 = true;
    }

    function f2() public {
        require(state1);
        require(!state2);
        state2 = true;
    }

    function f3() public {
        require(state2);
        require(!state3);
        state3 = true;
    }

    function echidna_oracle() public view returns (bool) {
        return (!state3);
    }

    function ether_oracle() public {
        require(state3);
        selfdestruct(msg.sender);
    }
}
