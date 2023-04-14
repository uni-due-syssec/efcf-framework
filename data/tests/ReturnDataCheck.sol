pragma solidity 0.7.6;

abstract contract Target {
    function r() public view virtual returns (uint256);
}

contract ReturnDataCheck {
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

    function solve(uint256 input) public {
        require(address(t) != address(0));

        require(t.r() == 12345678);

        // bug
        selfdestruct(msg.sender);
    }
}
