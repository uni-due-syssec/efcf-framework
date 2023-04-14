pragma solidity 0.7.6;

contract Calldata1 {
    function deposit() public payable {}

    function solve(string calldata input) public {
        bytes memory bInput = bytes(input);
        if (bInput[0] == "A" && bInput[1] == "B") {
            msg.sender.transfer(address(this).balance);
        }
    }
}
