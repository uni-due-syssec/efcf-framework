pragma solidity 0.7.6;

contract secondary {
    address owner;
    uint256 funds = 0;

    constructor(address _owner) payable {
        owner = _owner;
    }

    function give() public {
        if (funds > 0) {
            uint256 amount = funds;
            funds = 0;
            payable(msg.sender).transfer(amount);
        }
    }

    receive() external payable {
        funds += msg.value;
    }
}

contract multire3 {
    secondary sec;

    constructor(secondary _sec) payable {
        sec = _sec;
    }

    function receiveFunds() public payable {
        if (address(this).balance > 0) {
            payable(sec).transfer(address(this).balance);
        }
    }

    function enter() public payable {
        receiveFunds();
        msg.sender.call("");
        sec.give();
    }
}
