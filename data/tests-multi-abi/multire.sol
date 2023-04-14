pragma solidity 0.7.6;

contract secondary {
    address owner;
    bool flag = false;

    constructor(address _owner) payable {
        owner = _owner;
    }

    function set(bool _flag) public {
        flag = _flag;
    }

    function get() public returns (bool) {
        /* require(msg.sender == owner); */
        return flag;
    }

    receive() external payable {}
}

contract multire {
    secondary sec;
    bool state = false;

    constructor(secondary _sec) payable {
        sec = _sec;
    }

    function state_setup() public {
        sec.set(false);

        msg.sender.call("");

        if (sec.get() == true) {
            state = true;
        }
    }

    function trigger() public {
        require(state);
        payable(msg.sender).transfer(address(this).balance);
    }
}
