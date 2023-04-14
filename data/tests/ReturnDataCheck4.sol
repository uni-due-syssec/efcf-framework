pragma solidity 0.7.6;

abstract contract Target {
    function r() public view virtual returns (uint256);
}

contract ReturnDataCheck4 {
    Target private t;

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
        uint256 h = uint256(
            keccak256(abi.encode(uint256(keccak256(abi.encode(0x1337)))))
        );
        require(t.r() == h);

        // bug
        selfdestruct(msg.sender);
    }
}
