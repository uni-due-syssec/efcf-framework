/*
 * original version:
 * @source: http://blockchain.unica.it/projects/ethereum-survey/attacks.html#simpledao
 * @author: Atzei N., Bartoletti M., Cimoli T
 * Modified by Josselin Feist
 * Modified by Michael Rodler
 */
pragma solidity 0.7.6;

contract SimpleDAO {
    mapping(address => uint256) public credit;

    function deposit() public payable {
        credit[msg.sender] += msg.value;
    }

    function withdraw(uint256 amount) public {
        if (credit[msg.sender] >= amount) {
            msg.sender.call{value: amount}("");
            credit[msg.sender] -= amount;
        }
    }

    function queryCredit(address to) public view returns (uint256) {
        return credit[to];
    }
}
