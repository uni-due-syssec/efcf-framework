pragma solidity 0.7.6;

contract ParityWalletBugSuicide {
    address payable owner;

    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }

    function _ParityWalletBug() public {
        owner = msg.sender;
    }

    function kill() public onlyOwner {
        selfdestruct(owner);
    }

    function deposit() public payable {}
}
