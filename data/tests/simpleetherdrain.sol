pragma solidity 0.7.6;

contract SimpleEtherDrain {
    function withdraw() public {
        payable(msg.sender).transfer(address(this).balance);
    }

    function deposit() public payable {}
}
