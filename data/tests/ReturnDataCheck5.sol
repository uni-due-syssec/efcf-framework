pragma solidity 0.7.6;

abstract contract Target {
    function r()
        public
        view
        virtual
        returns (
            uint32,
            uint64,
            bytes32
        );
}

contract ReturnDataCheck5 {
    Target private t = Target(address(0));
    uint64 c64 = 0xdeadbeefdeadbeef;

    constructor() payable {}

    function set_address(address _t) public payable {
        // one time initializer
        require(address(t) == address(0));
        require(_t != address(0));
        t = Target(_t);
    }

    function solve() public {
        require(address(t) != address(0));

        // check
        (uint32 a, uint64 b, bytes32 c) = t.r();
        require(a == 0x1337);
        require(b + 1 == c64);
        require(
            c ==
                bytes32(
                    0xf05512c050202b5f165be884f32db2bd0fe222195e8f163f2fab6680dfc7f7f3
                )
        );

        // bug
        selfdestruct(msg.sender);
    }
}
