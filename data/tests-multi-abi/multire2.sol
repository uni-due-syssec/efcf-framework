pragma solidity 0.7.6;

interface IsInTransaction {
    function is_in_tx() external view returns (bool);
}

contract secondary {
    IsInTransaction owner;

    constructor() payable {
        owner = IsInTransaction(msg.sender);
    }

    function boom() public {
        require(owner.is_in_tx());
        uint256 amount = address(this).balance;
        payable(msg.sender).transfer(amount);
    }

    receive() external payable {}
}

contract multire2 is IsInTransaction {
    secondary sec;
    bool are_we_in_tx = false;

    constructor(secondary _sec) payable {
        sec = _sec;
    }

    function is_in_tx() external view override returns (bool) {
        return are_we_in_tx;
    }

    function receiveFunds() public payable {
        if (msg.value > 0) {
            payable(sec).transfer(msg.value);
        }
    }

    function reenter() public payable {
        are_we_in_tx = true;
        receiveFunds();

        msg.sender.call("");

        are_we_in_tx = false;
    }
}
