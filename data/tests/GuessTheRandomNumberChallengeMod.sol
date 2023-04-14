// from https://capturetheether.com/challenges/lotteries/guess-the-random-number/

pragma solidity ^0.7.6;

contract GuessTheRandomNumberChallengeMod {
    receive() external payable {}

    function isComplete() public view returns (bool) {
        return address(this).balance == 0;
    }

    function guess(uint8 n) public payable {
        require(msg.value == 1 ether);
        uint256 answer = uint8(
            uint256(
                keccak256(
                    abi.encodePacked(blockhash(block.number), block.timestamp)
                )
            )
        );

        if (n == answer) {
            msg.sender.transfer(2 ether);
        }
    }
}
