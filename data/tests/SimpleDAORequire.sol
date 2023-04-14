/*
 * original version:
 * @source: http://blockchain.unica.it/projects/ethereum-survey/attacks.html#simpledao
 * @author: Atzei N., Bartoletti M., Cimoli T
 * Modified by Josselin Feist
 * Modified by Michael Rodler
 */
pragma solidity 0.7.6;

contract SimpleDAORequire {
    mapping(address => uint256) public credit;

    /*
  function donate(address to) payable public{
    credit[to] += msg.value;
  }
  */

    function deposit() public payable {
        credit[msg.sender] += msg.value;
    }

    function withdraw(uint256 amount) public {
        if (credit[msg.sender] >= amount) {
            (bool r, ) = msg.sender.call{value: amount}("");
            require(r);
            credit[msg.sender] -= amount;
        }
    }

    function queryCredit(address to) public view returns (uint256) {
        return credit[to];
    }
}
