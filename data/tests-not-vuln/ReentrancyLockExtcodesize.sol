pragma solidity ^0.7.6;

contract ReentrancyLockExtcodesize {
    mapping(address => uint256) private credit;

    // this can be bypassed when called from a contract constructor
    function isContract(address _addr) private view returns (bool) {
        uint32 size;
        assembly {
            size := extcodesize(_addr)
        }
        return (size > 0);
    }

    modifier onlyEOA() {
        require(!isContract(msg.sender));
        _;
    }

    // could also be called by a contract during construction
    function deposit() public payable onlyEOA {
        credit[msg.sender] += msg.value;
    }

    // could also be called by a contract, but *cannot* be reentered; if the
    // contract does not have code it cannot trigger reentrancy
    function withdraw(uint256 amount) public onlyEOA {
        if (credit[msg.sender] >= amount) {
            msg.sender.call{value: amount}("");
            credit[msg.sender] -= amount;
        }
    }
}
