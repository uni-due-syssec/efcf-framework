pragma solidity 0.7.6;

contract NumberConstraints {
    uint256 answer = 42;
    uint256 lastguess = 0;
    uint256 lasttime = 0;

    receive() external payable {}

    function guess(
        uint256 n,
        uint256 m,
        uint256 o
    ) public payable {
        require(msg.value >= 1 ether);
        if (
            lastguess == 0 ||
            block.number > (lastguess + 10) ||
            block.timestamp > (lasttime + 10 weeks)
        ) {
            lastguess = block.number;
            lasttime = block.timestamp;
            if (999 < m && m < 1337) {
                if (n == answer) {
                    if ((o & 0xffffff) * 2 == m) {
                        msg.sender.transfer(address(this).balance);
                        /* selfdestruct(payable(msg.sender)); */
                    }
                }
            }
        }
    }
}
