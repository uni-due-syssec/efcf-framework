pragma solidity 0.7.6;

contract dispenser {
    mapping(bytes32 => address payable) to;
    mapping(bytes32 => uint256) amount;

    function register(
        bytes32 _id,
        address payable _to,
        uint256 _amount
    ) public payable {
        require(to[_id] == address(0));
        require(msg.value >= _amount);
        to[_id] = _to;
        amount[_id] = _amount;
    }

    function dispense_all(bytes32 _id) public {
        require(to[_id] != address(0));
        require(amount[_id] > 0);
        uint256 a = amount[_id];
        amount[_id] = 0;
        address payable t = to[_id];
        to[_id] = address(0);
        t.transfer(a);
    }

    function dispense(bytes32 _id, uint256 _amount) public {
        require(to[_id] != address(0));
        require(_amount > 0);
        amount[_id] -= _amount; // integer-overflow bug
        require(amount[_id] > 0); // useless "IO" check
        to[_id].transfer(_amount);
    }

    receive() external payable {}

    constructor() payable {}
}
