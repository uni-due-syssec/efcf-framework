pragma solidity 0.7.6;

contract SimpleEtherDrainOther {
    function withdraw(address payable to) public {
        require(msg.sender != to);
        to.transfer(address(this).balance);
    }

    function deposit() public payable {}
}
