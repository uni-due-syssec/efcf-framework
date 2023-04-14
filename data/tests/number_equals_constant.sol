pragma solidity 0.7.6;

contract NumberEqualsConstant {
    function guess(uint8 n) public payable {
        if (n == 42) {
            msg.sender.transfer(address(this).balance);
        }
    }
}
