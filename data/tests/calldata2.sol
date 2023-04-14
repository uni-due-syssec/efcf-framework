pragma solidity 0.7.6;

contract Calldata2 {
    function deposit() public payable {}

    function solve(string calldata input) public {
        bytes memory byteInput = bytes(input);
        if (byteInput[0] == "A" && byteInput[300] == "B") {
            selfdestruct(msg.sender);
        }
    }
}
