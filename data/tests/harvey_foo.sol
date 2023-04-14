pragma solidity 0.7.6;

contract HarveyFoo {
    int256 private x;
    int256 private y;
    bool private state;

    constructor() public payable {
        x = 0;
        y = 0;
        state = false;
    }

    function Bar() public returns (int256) {
        if (x == 42) {
            state = true;
            return 1;
        }
        return 0;
    }

    function SetY(int256 ny) public {
        y = ny;
    }

    function IncX() public {
        x++;
    }

    function CopyY() public {
        x = y;
    }

    function echidna_assert() public view returns (bool) {
        return !state;
    }

    // ether oracle
    function ether_oracle() public {
        require(state);
        payable(msg.sender).transfer(address(this).balance);
    }
}
