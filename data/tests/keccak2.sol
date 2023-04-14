pragma solidity 0.7.6;

contract keccak2 {
    bytes32 private commitment;

    function store(uint256 input) public {
        commitment = keccak256(abi.encodePacked(input));
    }

    function solve(uint256 input) public {
        if (keccak256(abi.encodePacked(input)) == commitment) {
            /* msg.sender.transfer(address(this).balance); */
            selfdestruct(payable(msg.sender));
        }
    }

    function deposit() public payable {}
}
