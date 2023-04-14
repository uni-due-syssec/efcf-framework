// very loosely based on https://github.com/crytic/echidna/blob/master/examples/solidity/coverage/boolean.sol
pragma solidity 0.7.6;

contract BooleanSelector {
    uint256 state = 0;

    constructor() payable {}

    function f(bool sel, bool b) public payable {
        if (sel) {
            if (state == 0) {
                state += 1;
            } else {
                state = 255;
            }
        } else {
            if (state == 1) {
                state += 1;
            } else {
                state = 255;
            }
        }
        require(b);
    }

    function echidna_oracle() public view returns (bool) {
        return state != 2;
    }

    function ether_oracle() public {
        require(state == 2);
        selfdestruct(msg.sender);
    }
}
