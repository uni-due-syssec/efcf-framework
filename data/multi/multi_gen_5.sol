pragma solidity ^0.7;

contract multi_gen_5 {
    bool state1 = false;
    bool state2 = false;
    bool state3 = false;
    bool state4 = false;
    bool state5 = false;

    constructor() payable {}

    function f1(uint256 arg0) public {
        require(arg0 == 1);
        state1 = true;
    }

    function f2(
        uint256 arg0,
        uint256 arg1,
        uint256 arg2,
        uint256 arg3
    ) public {
        require(state1);
        require(arg0 <= 42);
        require(!state2);
        require(arg1 <= arg2);
        require(
            arg2 >=
                115792089237316195423570985008687907853269984665640564039457584007913129639835
        );
        require(arg3 == arg2);
        state2 = true;
    }

    function f3(uint256 arg0, uint256 arg1) public {
        require(state2);
        require(arg0 >= arg1);
        require(arg1 == 10000);
        state3 = true;
    }

    function f4(
        uint256 arg0,
        uint256 arg1,
        uint256 arg2,
        uint256 arg3,
        uint256 arg4,
        uint256 arg5
    ) public {
        require(state3);
        require(arg0 <= 340282366920938463463374607431768211456);
        require(!state4);
        require(arg1 <= arg2);
        require(
            arg2 >=
                517695587919213252390520185012446518082551735177306785108667352555390569
        );
        require(arg3 == arg4);
        require(arg4 >= arg5);
        require(arg5 == 1);
        state4 = true;
    }

    function f5(
        uint256 arg0,
        uint256 arg1,
        uint256 arg2
    ) public {
        require(state4);
        require(arg0 <= 42);
        require(!state5);
        require(arg1 <= arg2);
        require(
            arg2 >=
                115792089237316195423570985008687907853269984665640564039457584007913129639835
        );
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
