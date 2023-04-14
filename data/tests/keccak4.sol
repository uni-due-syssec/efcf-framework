pragma solidity 0.7.6;

contract keccak4 {
    bytes32 private commitment;

    /*
    // a fuzzer that traces return values can essentially learn the right
    // sha3 commitment value by calling this function and looking at the
    // returned data.
    function calc_commitment(uint256 input) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(input));
    }
    */

    function commit(bytes32 _c) public {
        commitment = _c;
    }

    function solve(uint256 input) public {
        bytes32 h = keccak256(
            abi.encodePacked(keccak256(abi.encodePacked(input)))
        );
        bytes32 c = keccak256(abi.encodePacked(commitment));
        if (h == c) {
            /* msg.sender.transfer(address(this).balance); */
            selfdestruct(payable(msg.sender));
        }
    }

    function deposit() public payable {}

    receive() external payable {}
}
