pragma solidity 0.7.6;

contract InitBalance2 {
    constructor() payable {}

    function check() public {
        msg.sender.transfer(0x47bf39d196cda15100000000);
    }
}
