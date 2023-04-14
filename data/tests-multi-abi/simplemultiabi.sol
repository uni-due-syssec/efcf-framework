pragma solidity 0.7.6;

contract secondary {
    address payable main;
    bool public wat;

    constructor() payable {
        wat = false;
    }

    function boom() public {
        wat = true;
    }

    function check_wat() public returns (bool) {
        return wat;
    }

    receive() external payable {
        wat = false;
        uint256 amount = address(this).balance;
        if (amount > 0) {
            main.transfer(amount);
        }
    }
}

contract simplemultiabi {
    secondary sec;

    constructor(secondary _sec) payable {
        sec = _sec;
    }

    receive() external payable {}

    function trigger() public payable {
        if (sec.check_wat()) {
            payable(msg.sender).transfer(address(this).balance);
        }
    }
}
