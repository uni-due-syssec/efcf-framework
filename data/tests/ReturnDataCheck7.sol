pragma solidity 0.7.6;

contract ReturnDataCheck7 {
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

    function solve(address provider) public {
        (bool b, bytes memory input) = provider.call("");
        require(b);
        require(memcmp(input, bytes(hex"00010203040506070809")));
        selfdestruct(msg.sender);
    }
}
