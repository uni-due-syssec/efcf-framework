pragma solidity 0.7.6;

contract CallValue2 {
    constructor() payable {}

    function check() public payable {
        require(msg.value == 0x96cda15100000000);
        msg.sender.transfer(address(this).balance);
    }
}
