/*
 * @source: https://smartcontractsecurity.github.io/SWC-registry/docs/SWC-118#incorrect-constructor-name1sol
 * @author: Ben Perez
 * @vulnerable_at_lines: 18
 */


pragma solidity ^0.4.24;

contract incorrect_constructor_name2 {
    address private owner;

    modifier onlyowner {
        require(msg.sender==owner);
        _;
    }
    // <yes> <report> ACCESS_CONTROL
    function Incorrect_constructor_name2()
        public
    {
        owner = msg.sender;
    }

    function () payable {}

    function withdraw()
        public
        onlyowner
    {
       owner.transfer(this.balance);
    }
}
