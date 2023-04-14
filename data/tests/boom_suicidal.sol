// adapted/inspired by https://github.com/crytic/echidna/blob/4a4518b89a90f6663f39a1feb48c31fda76235cb/examples/solidity/exercises/simple.sol

pragma solidity 0.7.6;

contract BoomSuicidal {
    uint256 private counter = 2**200;
    bool allow_boom = false;

    function inc(uint256 val) public payable returns (uint256) {
        uint256 tmp = counter;
        counter += val;
        if (tmp > counter) {
            allow_boom = true;
        } else {
            return (counter - tmp);
        }
        return 0;
    }

    function boom() public {
        require(allow_boom);
        selfdestruct(msg.sender);
    }

    function echidna_has_boom() public view returns (bool) {
        return !allow_boom;
    }

    function deposit() public payable {}
}
