pragma solidity 0.7.6;

contract NumberEqualsStorageHashed {
    uint32 answer = 0xc0feef0c;

    function guess(bytes32 n) public payable {
        bytes32 hanswer = keccak256(abi.encode(answer));
        if (n == hanswer) {
            msg.sender.transfer(address(this).balance);
        }
    }
}
