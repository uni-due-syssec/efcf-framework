pragma solidity 0.7.6;

interface IFoobar {
    function lol() external view returns (uint256);
}

contract basic_hard {
    uint256 state = 0;
    bool sub1 = false;
    bool sub2 = false;
    bool[2] sub3;

    constructor() payable {}

    function addnflip(bool b) internal returns (bool) {
        if (b) {
            state -= 1;
        } else {
            state += 1;
        }
        return !b;
    }

    // inspired by https://github.com/crytic/echidna/blob/master/examples/solidity/coverage/single.sol
    function first(
        uint256 x,
        uint256 y,
        uint256 z
    ) public {
        require(x == 42424242);
        require(y == 8);
        require(z == 123);
        sub1 = addnflip(sub1);
    }

    function second() public payable {
        require(msg.value > 0);
        if (msg.value == 10000) {
            sub2 = addnflip(sub2);
        } else {
            state -= 1;
        }
    }

    // symex killer; lol
    function third(IFoobar[] calldata bars) public {
        for (uint256 i = 0; i < bars.length; i++) {
            if (bars[i].lol() == 1337) {
                if (i < sub3.length) {
                    sub3[i] = addnflip(sub3[i]);
                } else {
                    state -= 1;
                }
            } else {
                state -= 1;
            }
        }
    }

    function echidna_state() public view returns (bool) {
        return state != 4;
    }

    function ether_oracle() public {
        require(state == 4);
        selfdestruct(msg.sender);
    }
}
