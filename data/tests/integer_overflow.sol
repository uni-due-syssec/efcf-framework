contract IntegerOverflowConstraints {
    bool state = false;

    constructor() public payable {}

    function set_state() public {
        state = true;
    }

    function trigger(uint256 x, uint256 y) public {
        require(state);
        require(x == 9999);
        uint256 res = (x + y);
        require(res < x); // only satisfiable via IO
        selfdestruct(msg.sender);
    }
}
