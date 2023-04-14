// exploiting this is entirely possible.
// 1. call `initialize` from contract while in constructor
// 2. call `trigger` from contract after constructor -> allows for callbacks

pragma solidity 0.7.6;

contract NoCodeCallReturns {
    address addr;

    function initialize() public {
        // call only once to initialize
        require(addr == address(0));

        address _addr = msg.sender;
        uint256 _codeLength;
        assembly {
            _codeLength := extcodesize(_addr)
        }
        require(_codeLength == 0, "AAAA sorry humans only");

        // addr can never ever be a contract, always EOA!... NOT
        addr = _addr;
    }

    function trigger() public {
        require(addr != address(0));

        // transfer Ether
        uint256 a = address(this).balance;
        (bool b, bytes memory data) = addr.call{value: a}("asdf");

        // perform some check on the return data.
        require(b, "BBBB call failed");
        require(data.length == 32, "CCCC not enough return data");
        uint256 idata = 0;
        assembly {
            idata := mload(add(data, 0x20))
        }
        require(
            idata == 0x00010203040506070809,
            "DDDD return data check failed"
        );
    }

    receive() external payable {}

    constructor() payable {}
}

/*
contract Attack {
    NoCodeCallReturns t;

    constructor(address payable _target) payable {
        t = NoCodeCallReturns(_target);
        t.initialize();
    }

    fallback() external payable {
        assert(address(t) != address(0));
        t.trigger();
    }
}
*/
