pragma solidity 0.7.6;

contract NumberEqualsConstantLarge {
    function guess(uint256 n) public payable {
        if (
            n ==
            0xeb153b29ecda137a053bc2e2e68c282349dd4777ea488ba0ee385c61c8684f5c
        ) {
            msg.sender.transfer(address(this).balance);
        }
    }
}
