pragma solidity 0.7.6;

contract TeetherTest2SingleSha {
    constructor() payable {}

    receive() external payable {}

    function withdraw(
        address to,
        uint256 key,
        uint256 amount,
        bytes32 check
    ) public {
        require((key ^ 0xcafebabe) == (0x0badf00d ^ amount));
        require(check == keccak256(abi.encodePacked(to, key, amount)));
        payable(to).transfer(amount);
    }
}
