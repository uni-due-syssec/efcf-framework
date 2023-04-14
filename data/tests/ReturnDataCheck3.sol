pragma solidity 0.7.6;

abstract contract Target {
    function r() public view virtual returns (string memory);
}

contract ReturnDataCheck3 {
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
        bytes memory result = bytes(t.r());
        require(
            result.length >= 32 &&
                result[0] == "A" &&
                result[1] == "B" &&
                result[3] == "C" &&
                result[9] == "D"
        );

        // bug
        selfdestruct(msg.sender);
    }
}
