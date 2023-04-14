pragma solidity 0.7.6;

contract basic {
    uint256 state = 0;

    constructor() payable {}

    // inspired by https://github.com/crytic/echidna/blob/master/examples/solidity/coverage/single.sol
    function first(
        uint256 x,
        uint256 y,
        uint256 z
    ) public {
        require(x == 42424242);
        require(y == 8);
        require(z == 123);
        require(state == 0);
        state += 1;
    }

    function second() public payable {
        require(state == 1);
        require(msg.value > 0);
        if (msg.value == 10000) {
            state += 1;
        } else {
            state -= 1;
        }
    }

    function echidna_state() public view returns (bool) {
        return state != 2;
    }

    function ether_oracle() public {
        require(state == 2);
        selfdestruct(msg.sender);
    }
}
