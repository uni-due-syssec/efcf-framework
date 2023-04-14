// based on https://github.com/crytic/echidna/blob/master/examples/solidity/coverage/multi.sol

pragma solidity 0.7.6;

contract MultiHard {
    bool state1 = false;
    bool state2 = false;
    bool state3 = false;

    function f(uint256 x) public {
        require(x == 12);
        state1 = true;
    }

    function f_fake(uint256 x) public {
        require(x == 12);
        state1 = false;
    }

    function g(uint256 y) public {
        require(state1);
        require(y == 8);
        state2 = true;
    }

    function g_fake(uint256 y) public {
        require(state1);
        require(y == 8);
        state2 = false;
    }

    function h(uint256 z) public {
        require(state2);
        require(z == 0x1337);
        state3 = true;
    }

    function h_fake(uint256 z) public {
        require(state2);
        require(z == 0x1337);
        state3 = false;
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
