pragma solidity ^0.7;

contract multi_gen_9 {
    bool state1 = false;
    bool state2 = false;
    bool state3 = false;
    bool state4 = false;
    bool state5 = false;
    bool state6 = false;
    bool state7 = false;
    bool state8 = false;
    bool state9 = false;

    constructor() payable {}

    function f1(
        uint256 arg0,
        uint256 arg1,
        uint256 arg2,
        uint256 arg3,
        uint256 arg4
    ) public {
        require(!state1);
        require(arg0 <= arg1);
        require(arg1 >= 1);
        require(arg2 == arg3);
        require(arg3 >= arg4);
        require(arg4 == 42);
        state1 = true;
    }

    function f2(
        uint256 arg0,
        uint256 arg1,
        uint256 arg2,
        uint256 arg3,
        uint256 arg4,
        uint256 arg5
    ) public {
        require(state1);
        require(
            arg0 <=
                115792089237316195423570985008687907853269984665640564039457584007913129639835
        );
        require(!state2);
        require(arg1 <= arg2);
        require(arg2 >= 10000);
        require(arg3 == arg4);
        require(arg4 >= arg5);
        require(arg5 == 340282366920938463463374607431768211456);
        state2 = true;
    }

    function f3(
        uint256 arg0,
        uint256 arg1,
        uint256 arg2
    ) public {
        require(state2);
        require(
            arg0 <=
                517695587919213252390520185012446518082551735177306785108667352555390569
        );
        require(!state3);
        require(arg1 <= arg2);
        require(arg2 >= 1);
        state3 = true;
    }

    function f4(uint256 arg0) public {
        require(state3);
        require(arg0 == 42);
        state4 = true;
    }

    function f5(uint256 arg0, uint256 arg1) public {
        require(state4);
        require(arg0 >= arg1);
        require(
            arg1 ==
                115792089237316195423570985008687907853269984665640564039457584007913129639835
        );
        state5 = true;
    }

    function f6(uint256 arg0) public {
        require(state5);
        require(arg0 <= 10000);
        state6 = true;
    }

    function f7(
        uint256 arg0,
        uint256 arg1,
        uint256 arg2
    ) public {
        require(state6);
        require(!state7);
        require(arg0 <= arg1);
        require(arg1 >= 340282366920938463463374607431768211456);
        require(arg2 == arg1);
        state7 = true;
    }

    function f8(
        uint256 arg0,
        uint256 arg1,
        uint256 arg2,
        uint256 arg3
    ) public {
        require(state7);
        require(arg0 >= arg1);
        require(
            arg1 ==
                517695587919213252390520185012446518082551735177306785108667352555390569
        );
        require(arg2 <= 1);
        require(!state8);
        require(arg3 <= arg2);
        state8 = true;
    }

    function f9(
        uint256 arg0,
        uint256 arg1,
        uint256 arg2,
        uint256 arg3,
        uint256 arg4,
        uint256 arg5
    ) public {
        require(state8);
        require(arg0 >= 42);
        require(arg1 == arg2);
        require(arg2 >= arg3);
        require(
            arg3 ==
                115792089237316195423570985008687907853269984665640564039457584007913129639835
        );
        require(arg4 <= 10000);
        require(!state9);
        require(arg5 <= arg4);
        state9 = true;
    }

    function echidna_oracle() public view returns (bool) {
        return (!state9);
    }

    function ether_oracle() public {
        require(state9);
        selfdestruct(msg.sender);
    }
}
