// from: https://capturetheether.com/challenges/lotteries/guess-the-secret-number/

pragma solidity 0.7.6;

contract GuessTheSecretNumberChallengeMod {
    bytes32 answerHash =
        0xdb81b4d58595fbbbb592d3661a34cdca14d7ab379441400cbfa1b78bc447c365;

    constructor() payable {}

    receive() external payable {}

    function isComplete() public view returns (bool) {
        return address(this).balance == 0;
    }

    function guess(uint8 n) public payable {
        if (keccak256(abi.encodePacked(n)) == answerHash) {
            msg.sender.transfer(address(this).balance);
        }
    }
}
