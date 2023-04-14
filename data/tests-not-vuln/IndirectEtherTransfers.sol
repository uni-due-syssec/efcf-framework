pragma solidity ^0.7;

contract IndirectEtherTransfers {
  mapping (address => uint) public balances;
   
  function deposit() public payable {
    balances[msg.sender] += msg.value;
  }
    
  function withdraw(uint amount) public {
    require(balances[msg.sender] >= amount);
    balances[msg.sender] -= amount;
    payable(msg.sender).transfer(amount);
  }

  function transfer(address to, uint amount) public {
    require(balances[msg.sender] >= amount);
    balances[msg.sender] -= amount;
    balances[to] += amount;
  }
}
