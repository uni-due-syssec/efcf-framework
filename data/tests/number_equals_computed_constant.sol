pragma solidity 0.7.6;

contract NumberEqualsComputedConstant {
    function guess(uint32 n) public payable {
        uint256 h = uint256(
            keccak256(abi.encode(uint256(keccak256(abi.encode(0x1337)))))
        );
        uint32 answer = uint32(h);

        if (n == answer) {
            msg.sender.transfer(address(this).balance);
        }
    }
}
