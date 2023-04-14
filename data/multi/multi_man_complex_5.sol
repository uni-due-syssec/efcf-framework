// This is an extremely hard synthetic test case for smart contract analysis
// tools, such as fuzzers or symbolic executors. It tests various capabilities
// of the solver on achieving per-function coverage as well as finding the
// right order of the transactions. For a human this is quite easy to solve, as
// you really need to call f1 up to f5 in that order and provide the right
// inputs. One such transaction sequence would be:
// f1(12)
// f2(9)
// f3(0) with value == 1 ether
// f4(0x8000000000000000000000000000000000000001)
// f5(101, 1, 102)
// => now use the oracle

pragma solidity ^0.7;

contract multi_man_complex_5 {
    bool state1 = false;
    bool state2 = false;
    bool state3 = false;
    bool state4 = false;
    bool final_state = false;

    constructor() payable {}

    function f1(uint256 x) public {
        // force (useless) data dependency to the final state
        require(!final_state);
        // must only be called once
        require(!state1);
        // test simple equality constraint
        require(x == 12);
        state1 = true;
    }

    function f2(uint256 y) public {
        require(state1 || state2);
        // test simple inequality/range constraints
        require(y > 8);
        require(y < 24);
        state2 = true;
    }

    function f3(uint256 z) public payable {
        require(state2);
        // must not be called after itself or f4
        // again -> more complex data dependencies
        require(!state3 && !state4);
        // simple 0 constraint
        require(z == 0);
        // test setting constraints on call value
        require(msg.value == 1 ether);
        state3 = true;
    }

    function f4(uint256 a, uint256 b) public {
        require(state3);
        require(a < b);
        // test whether the solver can also produce large integers within a
        // certain range.
        require(a > (1 << 159));
        require(a < (1 << 200));
        // flip the state4 variable if f4 is called after f5 or f7
        state4 = true && !final_state;
    }

    function f5(
        uint256 a,
        uint256 b,
        uint256 c
    ) public {
        require(state4);
        // test whether the solver can solve arithmetic constraints
        // (without falling back to the trivial solution)
        require(c != 0 && a != 0 && b != 0);
        require((a + b) == c);
        uint256 r = a * b;
        require(r > 100);
        require(r < 1000);

        // set the final state, which allow to trigger the bug oracle.
        final_state = true;
    }

    // some artificial bug oracles that should be supported by many tools

    function echidna_oracle() public view returns (bool) {
        return (!final_state);
    }

    function f_assertion() public view returns (bool) {
        assert(!final_state);
        return final_state;
    }

    function finish() public {
        require(final_state);
        selfdestruct(msg.sender);
    }
}
