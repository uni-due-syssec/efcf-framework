// from https://capturetheether.com/challenges/lotteries/guess-the-number/

pragma solidity 0.7.6;

contract GuessTheNumberChallengeMod1 {
    uint256 answer = 42;

    receive() external payable {}

    function isComplete() public view returns (bool) {
        return address(this).balance == 0;
    }

    function guess(uint256 n) public payable {
        // two constraints the fuzzer must identify
        // * proivde 42 as input (should be doable via dictionary)
        // * provide at least one ether call value

        require(msg.value >= 1 ether);

        if (n == answer) {
            msg.sender.transfer(msg.value * 2);
        }
    }
}
