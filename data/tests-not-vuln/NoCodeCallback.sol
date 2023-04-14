// I believe that this code pattern is impossible to exploit.

pragma solidity 0.7.6;

contract NoCodeCallback {
    function trigger() public {
        // first check if the sender "is human". this is a faulty check and can
        // be bypassed by a contract in construction.
        address _addr = msg.sender;
        uint256 _codeLength;
        assembly {_codeLength := extcodesize(_addr)}
        require(_codeLength == 0, "AAAA sorry humans only");

        // transfer Ether
        uint a = address(this).balance;
        (bool b, bytes memory data) = msg.sender.call{value: a}("asdf");
        // this will always succeed, since at this point the contract is
        // essentially an EOA, which does not reject any sent ether.
        require(b, "BBBB call failed");

        // impossible - a contract under construction cannot return any data!
        require(data.length == 32, "CCCC not enough return data");
        uint idata = 0;
        assembly { idata := mload(add(data, 0x20)) }
        require(idata == 0x00010203040506070809, "DDDD return data check failed");
    }

    receive() external payable {}
    constructor() public payable {}
}
