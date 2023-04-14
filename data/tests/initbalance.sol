pragma solidity 0.7.6;

contract InitBalance {
    constructor() payable {}

    function check() public {
        msg.sender.transfer(2 ether);
    }
}
