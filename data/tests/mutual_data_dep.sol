pragma solidity 0.7.6;

contract MutualDataDep {
    bool final_state = false;
    bool state1 = true;
    bool state2 = false;
    uint256 x = 0;

    constructor() payable {
        state1 = true;
        state2 = false;
    }

    function a() public payable {
        require(state1);
        require(!state2);
        // flip the states
        state1 = !state1;
        state2 = !state2;
        if (x == 5) {
            x = 0;
            final_state = true;
        }
    }

    function b() public payable {
        require(!state1);
        require(state2);
        // flip the states
        state1 = !state1;
        state2 = !state2;
        if (x < 5) {
            x += 1;
            final_state = false;
        }
    }

    // oracles:

    function echidna_assert() public view returns (bool) {
        return !final_state;
    }

    function ether_oracle() public {
        require(final_state);
        selfdestruct(msg.sender);
    }
}
