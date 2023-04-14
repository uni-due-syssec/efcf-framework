pragma solidity 0.7.6;

contract TeetherTest1Simple {
    constructor() payable {}

    receive() external payable {}

    function withdraw(
        address to,
        uint256 key,
        uint256 amount
    ) public {
        if ((key ^ 0xcafebabe) == (0x0badf00d ^ amount)) {
            payable(to).transfer(amount);
        }
    }
}
