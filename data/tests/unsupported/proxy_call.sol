pragma solidity ^0.4.21;

contract Proxy {
    address owner;
    Receiver rec = Receiver(0x86c249452ee469d839942e05b8492dbb9f9c70ac);

    modifier onlyOwner {
        assert(msg.sender == owner);
        _;
    }

    function overwriteOwner() {
        owner = msg.sender;
    }

    function callProxy(address _to) onlyOwner public {
        rec.sendMoney(_to);
    }
}

contract Receiver {
    address proxy = 0xad62f08b3b9f0ecc7251befbeff80c9bb488fe9;

    modifier onlyProxy {
        assert(msg.sender == proxy);
        _;
    }

    function sendMoney(address _to) onlyProxy public {
        _to.transfer(address(this).balance);
    }
}
