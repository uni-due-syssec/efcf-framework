pragma solidity 0.7.6;

contract Calldata4 {
    constructor() payable {}

    receive() external payable {}

    function memcmp(bytes memory a, bytes memory b) internal returns (bool) {
        if (a.length != b.length) {
            return false;
        }
        for (uint256 i = 0; i < a.length; i++) {
            if (a[i] != b[i]) {
                return false;
            }
        }
        return true;
    }

    function solve(bytes memory input) public {
        require(memcmp(input, bytes(hex"2a74430617dbb3c1a15b")));
        selfdestruct(msg.sender);
    }
}
