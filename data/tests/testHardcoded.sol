pragma solidity ^0.7.6;

contract DataStore {
    mapping(address => mapping(address => uint256)) data;

    function get(address key) public view returns (uint256) {
        return data[msg.sender][key];
    }

    function set(address key, uint256 val) public returns (uint256) {
        return data[msg.sender][key] = val;
    }
}

contract testHardcoded {
    bool state = false;

    function enter() public payable {
        DataStore d = DataStore(0xdeadbeefdeadbeef);
        uint256 x = d.get(msg.sender);
        uint256 y = d.get(msg.sender);
        require(x == y);
        uint256 z = x + 1;
        d.set(msg.sender, z);
        require(d.get(msg.sender) == z);
        if (d.get(msg.sender) == 10) {
            state = true;
        }
    }

    function bug() public payable {
        require(state);
        selfdestruct(msg.sender);
    }
}
