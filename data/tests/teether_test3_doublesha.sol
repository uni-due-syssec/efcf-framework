pragma solidity 0.7.6;

contract TeetherTest3DoubleSha {
    constructor() payable {}

    receive() external payable {}

    function withdraw(
        address to,
        uint256 key,
        uint256 amount,
        bytes32 check,
        bytes32 check2
    ) public {
        require(check == keccak256(abi.encodePacked(to, key, amount)));
        require(check2 == keccak256(abi.encodePacked(check)));
        address payable recipient = payable(to);
        if ((key ^ 0xcafebabe) == (0x0badf00d ^ amount)) {
            recipient.transfer(amount);
        }
    }
}
