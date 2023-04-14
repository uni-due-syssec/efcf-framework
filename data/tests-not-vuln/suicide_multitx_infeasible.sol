// https://swcregistry.io/docs/SWC-106#suicide-multitx-infeasiblesol

pragma solidity ^0.7.6;

contract SuicideMultiTxInfeasible {
    uint256 private initialized = 0;
    uint256 public count = 1;

    function init() public {
        initialized = 1;
    }

    function run() public {
        if (initialized != 2) {
            return;
        }

        selfdestruct(msg.sender);
    }
    
    function deposit() public payable {}
}
