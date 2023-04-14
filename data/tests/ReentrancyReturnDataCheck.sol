pragma solidity 0.7.6;

abstract contract Target {
    function r() public view virtual returns (uint256);

    function v() public view virtual returns (uint256);

    function omg(uint256 oh) public payable virtual;

    function wtf(uint256 oh) public payable virtual;
}

contract ReentrancyReturnDataCheck {
    Target private t = Target(address(0));

    uint256[2] state;

    constructor() payable {
        t = Target(address(0));
        state[0] = 0;
        state[1] = 0;
    }

    function set_state(uint256 i, uint256 s) public {
        require(s > 0);
        require(i < 2);
        state[i] = s;
    }

    function set_address(address _t) public payable {
        // one time initializer
        require(address(t) == address(0));
        require(_t != address(0));
        t = Target(_t);
    }

    function solve(uint256 input) public {
        require(address(t) != address(0));

        state[0] = 0;

        require(t.r() == 12345678);
        require(t.r() == 12345678);

        require(t.v() == 0xdeadbeef01020304);
        // whether this is possible depends on whether this compiles down to a
        // staticcall or not.
        require(t.v() > 0xdeadbeef01020304);

        t.omg(input);
        // only possible with reentrant call to set_state
        require(state[0] > 0);

        state[1] = 0;
        t.wtf(input);
        // only possible with reentrant call to set_state
        require(state[1] > 0);

        // bug
        selfdestruct(msg.sender);
    }
}
