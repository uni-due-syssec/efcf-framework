pragma solidity ^0.7.6;

contract ReentrancyBuggyLock2 {
    mapping(address => uint256) private credit;
    address private disallow_reenter;

    // not so intelligent reentrancy guard :) as second colluding contract can
    // reset the guard.
    modifier noReenter() {
        require(disallow_reenter != msg.sender);
        disallow_reenter = msg.sender;
        _;
        disallow_reenter = address(0);
    }

    function deposit() public payable {
        credit[msg.sender] += msg.value;
    }

    function withdraw(uint256 amount) public noReenter {
        if (credit[msg.sender] >= amount) {
            msg.sender.call{value: amount}("");
            credit[msg.sender] -= amount;
        }
    }
}
