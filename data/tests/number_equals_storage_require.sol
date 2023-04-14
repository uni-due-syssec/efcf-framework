pragma solidity 0.7.6;

contract NumberEqualsStorageRequire {
    uint256 answer = 0xc0ffeeff;

    function guess(uint256 n) public payable {
        require(n == answer);
        msg.sender.transfer(address(this).balance);
    }
}
