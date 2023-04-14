// This is an extremely hard synthetic test case for smart contract analysis
// tools, such as fuzzers or symbolic executors. It tests various capabilities
// of the solver on achieving per-function coverage as well as finding the
// right order of the transactions. For a human this is quite easy to solve, as
// you really need to call f1 up to f9 in that order and provide the right
// inputs. One such transaction sequence would be:
// f1(12)
// f2(9)
// f3(0) with value == 1 ether
// f4(0x8000000000000000000000000000000000000001)
// f5(101, 1, 102)
// f6(address(this), 2)
// f7(0, 0xbeced09521047d05b8960b7e7bcc1d1292cf3e4b2a6b63f48335cbde5f7545d2, 42)
// f8(42)
// f9({5000, 1, 0, 0, 0})
// => now use the oracle

pragma solidity ^0.7;

contract multi_man_complex_9 {
    bool state1 = false;
    bool state2 = false;
    bool state3 = false;
    bool state4 = false;
    bool state5 = false;
    bool state6 = false;
    uint256 state7 = 0;
    bool state8 = false;
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
        state4 = true && !state5 && !state6;
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
        state5 = true;
    }

    function f6(address x, uint256 v) public payable {
        // ERC contracts often have similar constraints in some kind of
        // transfer functions
        require(msg.sender == x);
        require(v == 2 * msg.value);
        state6 = true;

        // we put the require at the end ¯\_(ツ)_/¯ maybe some solver don't
        // like this
        require(state5);
    }

    function f7(
        uint256,
        uint256 h,
        uint32 s
    ) public {
        require(state6);
        // we essentially compute a random constant here. This tests whether
        // the solver supports hashes in some way and whether it can solve
        // equality constraints on computed constant values, e.g., taint
        // tracking (or redqueen) will solve this.
        uint256 C = uint256(keccak256(abi.encode(42)));
        require(h == C);
        state7 = s;
    }

    function f8(uint256 x) public {
        require(state7 != 0);
        // the same value must be provided as the "s" parameter in the f6
        // transaction. For dataflow or symbolic analysis this means that
        // metadata must be tracked accross transactions. For a fuzzer this
        // should be rather easy to solve if the selection distribution for
        // uints are strongly biased towards some values.
        require(state7 == x);
        state8 = true;
    }

    function f9(uint256[] calldata arr) public {
        require(state8);
        // require array to be within a certain range. This is quite typical in
        // real world smart contracts as to avoid excessive gas costs.
        require(arr.length >= 5);
        require(arr.length <= 10);
        uint256 sum = 0;
        for (uint256 i = 0; i < arr.length; i++) {
            sum += arr[i];
        }
        // require the sum to be rather large, but also small when compared
        // to the bitwidth of the array members.
        require(sum > 5000);
        require(sum < 10000);

        // state4 can be reset to false again, so we check that it is still
        // true
        require(state4);

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