// from https://github.com/crytic/echidna/blob/master/examples/solidity/coverage/single.sol
pragma solidity 0.7.6;

contract Single {
    bool state = false;

    constructor() payable {}

    function f(
        uint256 x,
        uint256 y,
        uint256 z
    ) public {
        require(x == 42424242);
        require(y == 8);
        require(z == 123);
        state = true;
    }

    function echidna_state() public view returns (bool) {
        return !state;
    }

    function ether_oracle() public {
        require(state == true);
        selfdestruct(msg.sender);
    }
}
