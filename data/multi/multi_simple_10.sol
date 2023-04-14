pragma solidity ^0.7;

contract multi_simple_10 {
    bool state1 = false;
    bool state2 = false;
    bool state3 = false;
    bool state4 = false;
    bool state5 = false;
    bool state6 = false;
    bool state7 = false;
    bool state8 = false;
    bool state9 = false;
    bool state10 = false;

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

    function f6() public {
        require(state5);
        require(!state6);
        state6 = true;
    }

    function f7() public {
        require(state6);
        require(!state7);
        state7 = true;
    }

    function f8() public {
        require(state7);
        require(!state8);
        state8 = true;
    }

    function f9() public {
        require(state8);
        require(!state9);
        state9 = true;
    }

    function f10() public {
        require(state9);
        require(!state10);
        state10 = true;
    }

    function echidna_oracle() public view returns (bool) {
        return (!state10);
    }

    function ether_oracle() public {
        require(state10);
        selfdestruct(msg.sender);
    }
}
