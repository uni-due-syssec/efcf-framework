// from https://capturetheether.com/challenges/lotteries/guess-the-random-number/

pragma solidity ^0.7.6;

contract GuessTheRandomNumberChallenge {
    uint8 answer;

    constructor() payable {
        answer = uint8(
            uint256(
                keccak256(
                    abi.encodePacked(
                        blockhash(block.number - 1),
                        block.timestamp
                    )
                )
            )
        );
    }

    receive() external payable {}

    function isComplete() public view returns (bool) {
        return address(this).balance == 0;
    }

    function guess(uint8 n) public payable {
        require(msg.value == 1 ether);

        if (n == answer) {
            msg.sender.transfer(2 ether);
        }
    }
}
