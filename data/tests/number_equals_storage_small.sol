pragma solidity 0.7.6;

contract NumberEqualsStorageSmall {
    uint8 answer = 42;

    function guess(uint8 n) public payable {
        if (n == answer) {
            msg.sender.transfer(address(this).balance);
        }
    }
}
