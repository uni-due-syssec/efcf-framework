/*
 * original version:
 * @source: http://blockchain.unica.it/projects/ethereum-survey/attacks.html#simpledao
 * @author: Atzei N., Bartoletti M., Cimoli T
 * Modified by Josselin Feist
 * Modified by Michael Rodler
 */
pragma solidity ^0.7;

contract SimpleDAO {
  mapping (address => uint) public credit;
   
  /*
  function donate(address to) payable public{
    credit[to] += msg.value;
  }
  */

  function deposit() public payable {
    credit[msg.sender] += msg.value;
  }
    
  function withdraw(uint amount) public {
    if (credit[msg.sender] >= amount) {
      msg.sender.call{value: amount}("");
      credit[msg.sender] -= amount;
    }
  }

  function queryCredit(address to) view public returns(uint){
    return credit[to];
  }
}

