// from https://capturetheether.com/challenges/lotteries/guess-the-number/

pragma solidity 0.7.6;

contract GuessTheNumberChallenge {
    uint8 answer;

    constructor() payable {
        answer = 42;
    }

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
