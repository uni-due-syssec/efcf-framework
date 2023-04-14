pragma solidity 0.7.6;

contract NumberEqualsComputedConstantLargeDataType {
    function guess(uint256 n) public payable {
        uint256 h = uint256(
            keccak256(abi.encode(uint256(keccak256(abi.encode(0x1337)))))
        );
        uint256 answer = h & 0xffffffff;

        if (n == answer) {
            msg.sender.transfer(address(this).balance);
        }
    }
}
