pragma solidity 0.7.6;

contract harvey_baz {
    bool private state1 = false;
    bool private state2 = false;
    bool private state3 = false;
    bool private state4 = false;
    bool private state5 = false;

    function baz(
        int256 a,
        int256 b,
        int256 c
    ) public returns (int256) {
        int256 d = b + c;
        if (d < 1) {
            if (b < 3) {
                state1 = true;
                return 1;
            }
            if (a == 42) {
                state2 = true;
                return 2;
            }

            state3 = true;
            return 3;
        } else {
            if (c < 42) {
                state4 = true;
                return 4;
            }
            state5 = true;
            return 5;
        }
    }

    function echidna_all_states() public view returns (bool) {
        return !state1 || !state2 || !state3 || !state4 || !state5;
    }
}
