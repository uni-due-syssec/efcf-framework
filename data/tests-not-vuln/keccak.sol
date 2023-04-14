pragma solidity ^0.7;

contract keccak {
    uint256 commitment = uint256(0x00315dd8c17889952babe36aa03bfb657bb20339ad);

    function solve(uint256 input) public {
        if (keccak256(abi.encodePacked(input)) == bytes32(commitment)) {
            msg.sender.transfer(address(this).balance);
        }
    }

    function deposit() public payable {
    }
}
