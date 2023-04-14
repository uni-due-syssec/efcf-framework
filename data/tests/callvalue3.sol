pragma solidity 0.7.6;

contract CallValue3 {
    constructor() payable {}

    function check() public payable {
        uint256 h = uint256(
            keccak256(abi.encode(uint256(keccak256(abi.encode(0x1337)))))
        );
        uint32 amount = uint32(h);
        require(msg.value == uint256(amount));
        selfdestruct(msg.sender);
    }
}
