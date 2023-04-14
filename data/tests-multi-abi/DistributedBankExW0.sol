// Multi-DAO 3*: contracts/DistributedBankExW0.scif

pragma solidity 0.7.6;

contract DistributedBankExW0 {
    DistributedBankExW0 otherBank;
    mapping(address => uint256) balances;

    constructor(DistributedBankExW0 _other) {
        otherBank = _other;
    }

    function deposit() public payable {
        address gSender = msg.sender;
        uint256 gAmount = msg.value;

        balances[gSender] += gAmount;
        otherBank.incBal(gSender, gAmount);
    }

    function withdraw(uint256 amount) public {
        address payable gSender = payable(msg.sender);

        if (balances[gSender] >= amount && address(this).balance >= amount) {
            balances[gSender] = balances[gSender] - amount;
            (bool r, bytes memory _) = gSender.call{value: amount}("");
            require(r);
            otherBank.decBal(gSender, amount);
        }
    }

    function decBal(address user, uint256 amount) public {
        require(msg.sender == address(otherBank));
        balances[user] = balances[user] - amount;
    }

    function incBal(address user, uint256 amount) public {
        require(msg.sender == address(otherBank));
        balances[user] = balances[user] + amount;
    }

    function getBalance() public view returns (uint256) {
        return address(this).balance;
    }
}
