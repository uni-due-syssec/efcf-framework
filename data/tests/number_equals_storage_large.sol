pragma solidity 0.7.6;

contract NumberEqualsStorageLarge {
    uint256 answer =
        0xeb153b29ecda137a053bc2e2e68c282349dd4777ea488ba0ee385c61c8684f5c;

    function guess(uint256 n) public payable {
        if (n == answer) {
            msg.sender.transfer(address(this).balance);
        }
    }
}
