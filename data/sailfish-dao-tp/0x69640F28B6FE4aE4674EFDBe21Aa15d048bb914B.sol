pragma solidity ^0.4.15;

/**
 * Target smart contract.
 * For any suggestions please contact me at zhuangyuan20(at)outlook.com
 */
contract weeWhoo {
    mapping(address => uint256) public _balances;
    mapping(address => bool) private claimedBonus;
    address admin;
    uint256 public TotalAmount;

    function weeWhoo() public payable {
        admin = msg.sender;
        TotalAmount = msg.value;
    }

    function deposit() public payable {
        _balances[msg.sender] += msg.value;
        TotalAmount += msg.value;
        claimedBonus[msg.sender] = false;
    }

    function GetBonusWithdraw() public payable {
        if (claimedBonus[msg.sender] != true) {
            _balances[msg.sender] += 10;
            withdraw();
        }
        claimedBonus[msg.sender] = true;

        //  }
    }

    function withdraw() public payable {
        uint256 amount;
        amount = _balances[msg.sender];
        if (amount != 0) {
            _balances[msg.sender] -= amount;
            require(msg.sender.call.value(amount)(""));
        }
        TotalAmount -= amount;
    }

    function() external payable {
        TotalAmount += msg.value;
        revert();
    }

    function destroy() public {
        require(msg.sender == admin);
        selfdestruct(msg.sender);
    }
}
