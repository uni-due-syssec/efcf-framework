pragma solidity 0.7.6;

contract ParityWalletBugCall {
    address payable owner;

    modifier onlyOwner() {
        assert(msg.sender == owner);
        _;
    }

    function _ParityWalletBug() public {
        owner = msg.sender;
    }

    function send() public onlyOwner {
        owner.transfer(address(this).balance);
    }

    function deposit() public payable {}
}
