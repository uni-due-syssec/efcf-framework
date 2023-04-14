pragma solidity 0.7.6;

contract keccak3nopure {
    bytes32 private commitment;

    /*
    function calc_commitment(uint256 input) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(input));
    }
    */

    function commit(bytes32 _c) public {
        commitment = _c;
    }

    function solve(uint256 input) public {
        // this should be solvable by providing a fixed input and doing compare
        // logging of the commitment.
        if (keccak256(abi.encodePacked(input)) == commitment) {
            selfdestruct(payable(msg.sender));
        }
    }

    function deposit() public payable {}

    receive() external payable {}
}
