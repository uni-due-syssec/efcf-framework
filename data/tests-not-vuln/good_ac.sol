pragma solidity ^0.7.6;

contract good_ac {

    address payable owner;

    mapping (address => uint) balances;

    constructor() payable {
        owner = msg.sender;
    }

    modifier onlyOwner {
        require(msg.sender == owner);
        _;
    }


    function deposit() public payable {
        balances[msg.sender] += msg.value;
    }

    function withdraw() public {
        uint amount = balances[msg.sender];
        balances[msg.sender] = 0;
        msg.sender.transfer(amount);
    }

    function transferOwnership(address payable to) public onlyOwner {
        owner = to;
    }

    function kill() public onlyOwner {
        selfdestruct(owner);
    }
}
