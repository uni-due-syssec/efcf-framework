pragma solidity ^0.4.21;

contract Library {
    function send(address _to) public {
        _to.transfer(address(this).balance);
    }
}

contract Proxy {
    Library lib = 0xAACCBB;

    function() {
        lib.delegatecall(msg.data)
    }
}
