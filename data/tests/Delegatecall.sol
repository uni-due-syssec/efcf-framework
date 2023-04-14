pragma solidity 0.7.6;

contract Delegatecall {
    address owner;
    address lib;

    constructor() {
        owner = msg.sender;
    }

    function update_lib(address _lib) public {
        /* require(owner == msg.sender); */
        lib = _lib;
    }

    function update_owner(address _owner) public {
        require(owner == msg.sender);
        owner = _owner;
    }

    fallback() external {
        require(lib != address(0));
        lib.delegatecall(msg.data);
    }
}
