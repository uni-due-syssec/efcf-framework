// example adapted from https://github.com/crytic/echidna-parade/blob/afbc4cd7ffcf556a7d18b047a1ba08fad5713ba4/examples/justlen.sol

contract justlen128 {
    address[] add_array;

    bool lengthChecking = false;

    function push_1(address x) public {
        add_array.push(x);
    }

    function pop_1() public {
        if (add_array.length > 0) {
            add_array.pop();
        }
    }

    function double(address x) public {
        uint256 alen = add_array.length;
        for (uint256 i = 0; i < alen; i++) {
            add_array.push(x);
        }
    }

    function plus5(address x) public {
        uint256 alen = add_array.length;
        for (uint256 i = 0; i < 5; i++) {
            add_array.push(x);
        }
    }

    function halve() public {
        uint256 alen = add_array.length;
        for (uint256 i = 0; i < (alen / 2); i++) {
            add_array.pop();
        }
    }

    function decimate() public {
        uint256 alen = add_array.length;
        for (uint256 i = 0; i < ((alen * 9) / 10); i++) {
            add_array.pop();
        }
    }

    function empty1() public {
        delete add_array;
    }

    function empty2() public {
        delete add_array;
    }

    function empty3() public {
        delete add_array;
    }

    function turn_on_length_checking() public {
        lengthChecking = true;
    }

    function turn_off_length_checking() public {
        lengthChecking = false;
    }

    function test_long_128() public {
        if (add_array.length >= 128) {
            if (lengthChecking) {
                /*assert(false);*/
                selfdestruct(msg.sender);
            }
        }
    }
}
