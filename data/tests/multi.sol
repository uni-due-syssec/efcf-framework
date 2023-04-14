// adapted from https://github.com/crytic/echidna/blob/master/examples/solidity/coverage/multi.sol

pragma solidity 0.7.6;

contract Multi {
    bool state1 = false;
    bool state2 = false;
    bool state3 = false;

    function f(uint256 x) public {
        require(x == 12);
        state1 = true;
    }

    function g(uint256 y) public {
        require(state1);
        require(y == 8);
        state2 = true;
    }

    function h(uint256 z) public {
        require(state2);
        require(z == 0x1337);
        state3 = true;
    }

    function ul(uint256) public {
        uint256 x = 0;
    }

    function echidna_state3() public view returns (bool) {
        return (!state3);
    }

    function ether_oracle() public {
        require(state3);
        payable(msg.sender).transfer(address(this).balance);
    }

    receive() external payable {}
}
