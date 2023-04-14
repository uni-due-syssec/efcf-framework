pragma solidity 0.7.6;

abstract contract Target {
    function r()
        public
        view
        virtual
        returns (
            uint32,
            uint32,
            uint32,
            uint32,
            uint32
        );
}

contract ReturnDataCheck6 {
    Target private t = Target(address(0));

    constructor() payable {
        t = Target(address(0));
    }

    function set_address(address _t) public payable {
        // one time initializer
        require(address(t) == address(0));
        require(_t != address(0));
        t = Target(_t);
    }

    function solve() public {
        require(address(t) != address(0));

        // check
        (uint32 a, uint32 b, uint32 c, uint32 d, uint32 e) = t.r();
        require(a == 0x1337);
        require(b == a + 1);
        require(c == b + 1);
        require(d == c + 1);
        require(e == d + 1);

        // bug
        selfdestruct(msg.sender);
    }
}
