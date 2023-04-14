pragma solidity ^0.7;

contract multi_gen_3 {
    bool state1 = false;
    bool state2 = false;
    bool state3 = false;

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

    function echidna_oracle() public view returns (bool) {
        return (!state3);
    }

    function ether_oracle() public {
        require(state3);
        selfdestruct(msg.sender);
    }
}
