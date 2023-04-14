pragma solidity ^0.7;

abstract contract Bank {
    function transfer(uint amount) public virtual  payable returns(bool);
}

contract NoReentrancyDAOLocks {
  mapping (address => uint) credit;
  mapping (address => uint) locks;

  modifier locked {
      require(locks[msg.sender] == 0);
      locks[msg.sender] = 1;
      _;
      locks[msg.sender] = 0;
  }
   
  function deposit() public payable locked {
    credit[msg.sender] += msg.value;
  }

  function withdrawAllT() public locked {
    msg.sender.transfer(credit[msg.sender]);
    credit[msg.sender] = 0;
  }
  
  function withdrawAllC() public locked {
    Bank b = Bank(msg.sender);
    uint c = credit[msg.sender];

    require(b.transfer{value: c}(c));

    credit[msg.sender] = 0;
  }
}
