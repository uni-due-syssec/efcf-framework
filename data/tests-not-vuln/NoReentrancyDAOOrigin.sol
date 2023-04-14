pragma solidity ^0.7;

contract NoReentrancyDAOOriginCheck {
  mapping (address => uint) credit;
   
  function deposit() public payable {
    // can only be called by an EOA
    require(msg.sender == tx.origin);

    credit[msg.sender] += msg.value;
  }

  function withdrawAll() public {
    // can only be called by an EOA -> call back cannot reentern
    require(msg.sender == tx.origin);

    msg.sender.call{value: credit[msg.sender]}("");

    credit[msg.sender] = 0;
  }
}
