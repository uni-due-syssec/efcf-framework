// adapted from https://github.com/crytic/building-secure-contracts/blob/f6fa9ee43409db911341cdc15658f20edb8f915e/program-analysis/echidna/filtering-functions.md

contract CryticComplexExample {
    bool state1 = false;
    bool state2 = false;
    bool state3 = false;
    bool state4 = false;

    function f(uint256 x) public payable {
        require(x == 12);
        state1 = true;
    }

    function g(uint256 x) public payable {
        require(state1);
        require(x == 8);
        state2 = true;
    }

    function h(uint256 x) public payable {
        require(state2);
        require(x == 42);
        state3 = true;
    }

    function i() public payable {
        require(state3);
        state4 = true;
    }

    function reset1() public {
        state1 = false;
        state2 = false;
        state3 = false;
        return;
    }

    function reset2() public {
        state1 = false;
        state2 = false;
        state3 = false;
        return;
    }

    function echidna_state4() public view returns (bool) {
        return (!state4);
    }

    function selfdestruct_oracle() public payable {
        // allows efcf to discover the path
        if (state4) {
            selfdestruct(msg.sender);
        }
    }

    function deposit() public payable {}
}
