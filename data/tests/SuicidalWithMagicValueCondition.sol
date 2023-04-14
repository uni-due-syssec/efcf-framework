pragma solidity 0.7.6;

contract SuicidalWithMagicValueCondition {
    address payable owner;
    mapping(address => uint256) deposits;
    uint256 raised = 0;
    uint256 key = 0;

    constructor() {
        owner = msg.sender;
        raised = 0;
        key = uint256(keccak256(abi.encodePacked(block.number)));
    }

    function invest() public payable {
        deposits[msg.sender] += msg.value;
        raised += msg.value;
    }

    function destroy(uint256 provided_key) public {
        require(raised > 0);
        require(provided_key == key);
        selfdestruct(msg.sender);
    }
}
