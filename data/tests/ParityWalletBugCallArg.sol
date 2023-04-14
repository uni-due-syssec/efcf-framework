pragma solidity 0.7.6;

contract ParityWalletBugCallArg {
    address owner;

    modifier onlyOwner() {
        assert(msg.sender == owner);
        _;
    }

    function _ParityWalletBug() public payable {
        owner = msg.sender;
    }

    function send(address payable _to) public onlyOwner {
        _to.transfer(address(this).balance);
    }

    function deposit() public payable {}
}
