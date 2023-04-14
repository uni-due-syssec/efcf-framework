pragma solidity ^0.7.6;

contract ReentrancyVulnBankBuggyLock {
    mapping(address => uint256) private userBalances;
    mapping(address => bool) private disableWithdraw;

    function getBalance(address a) public view returns (uint256) {
        return userBalances[a];
    }

    function deposit() public payable {
        userBalances[msg.sender] += msg.value;
    }

    function transfer(address to, uint256 amount) public {
        if (userBalances[msg.sender] >= amount) {
            userBalances[to] += amount;
            userBalances[msg.sender] -= amount;
        }
    }

    function withdrawBalance() public {
        require(disableWithdraw[msg.sender] == false);

        uint256 amountToWithdraw = userBalances[msg.sender];

        if (amountToWithdraw > 0) {
            disableWithdraw[msg.sender] = true;
            msg.sender.call{value: amountToWithdraw}("");
            disableWithdraw[msg.sender] = false;

            userBalances[msg.sender] = 0;
        }
    }
}
