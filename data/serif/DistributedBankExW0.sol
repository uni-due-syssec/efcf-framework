// Multi-DAO 3*: contracts/DistributedBankExW0.scif

pragma solidity 0.7.6;

contract DistributedBank {
    DistributedBank otherBank;
    mapping(address => uint) balances;

    constructor(DistributedBank _other) {
        otherBank = _other;
    }

    function deposit() public payable {
        address gSender = msg.sender;
        uint gAmount = msg.value;

        if (balances[gSender] >= gAmount && address(this).balance >= gAmount) {
            balances[gSender] = balances[gSender] + gAmount;
            otherBank.incBal(gSender, gAmount);
        }
    }

    function withdraw(uint amount) public {
        address gSender = msg.sender;
        uint gAmount = amount;

        if (balances[gSender] >= gAmount && address(this).balance >= gAmount) {
            balances[gSender] = balances[gSender] - gAmount;
            (bool r, bytes memory _) = gSender.call{value: gAmount}("");
            require(r);
            otherBank.decBal(gSender, gAmount);
        }
    }

    function decBal(address user, uint amount) public {
        require(msg.sender == address(otherBank));
        balances[user] = balances[user] - amount;
    }

    function incBal(address user, uint amount) public {
        require(msg.sender == address(otherBank));
        balances[user] = balances[user] + amount;
    }

    function getBalance() public view returns(uint) {
        return address(this).balance;
    }
}
