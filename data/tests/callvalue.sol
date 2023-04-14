pragma solidity 0.7.6;

contract CallValue {
    constructor() payable {}

    function check() public payable {
        require(msg.value == 1 ether);
        msg.sender.transfer(address(this).balance);
    }
}
