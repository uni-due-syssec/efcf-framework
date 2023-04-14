pragma solidity ^0.7;

contract NoReentrancyDAO {
  mapping (address => uint) credit;
  mapping (address => uint) locks;
   
  function deposit() public payable {
    credit[msg.sender] += msg.value;
  }

  function withdrawAll() public {
    msg.sender.transfer(credit[msg.sender]);
    credit[msg.sender] = 0;
  }
}
