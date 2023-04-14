pragma solidity ^0.7;

contract multi_simple_9 {
    bool state1 = false;
    bool state2 = false;
    bool state3 = false;
    bool state4 = false;
    bool state5 = false;

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

    function f4() public {
        require(state3);
        require(!state4);
        state4 = true;
    }

    function f5() public {
        require(state4);
        require(!state5);
        state5 = true;
    }

    function echidna_oracle() public view returns (bool) {
        return (!state5);
    }

    function ether_oracle() public {
        require(state5);
        selfdestruct(msg.sender);
    }
}
