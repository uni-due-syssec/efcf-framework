pragma solidity 0.7.6;

contract NumberEqualsStorage {
    uint32 answer = 0xc0feef0c;

    function guess(uint32 n) public payable {
        if (n == answer) {
            msg.sender.transfer(address(this).balance);
        }
    }
}
