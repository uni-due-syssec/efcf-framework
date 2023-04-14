pragma solidity ^0.7.6;

contract UnconditionalReentrancyVulnBank {
    mapping(address => uint256) private userBalances;

    function getBalance(address a) public view returns (uint256) {
        return userBalances[a];
    }

    function deposit() public payable {
        userBalances[msg.sender] += msg.value;
    }

    function withdrawAll() public {
        uint256 amountToWithdraw = userBalances[msg.sender];

        // In this example VulnBank unconditionally sends ether to msg.sender.
        // The amount of ether might be 0, which will waste gas, but not do any
        // harm. However, an attacker can re-enter this function and exploit
        // the inconsistent state to drain the contract of ether.
        msg.sender.call{value: amountToWithdraw}("");

        userBalances[msg.sender] = 0;
    }
}
