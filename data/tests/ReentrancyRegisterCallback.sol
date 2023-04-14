pragma solidity 0.7.6;

interface ICallback {
    function transferred(
        address from,
        address to,
        uint256 amount
    ) external returns (bool);

    function withdrawn(address who, uint256 amount) external returns (bool);
}

contract ReentrancyRegisterCallback {
    mapping(address => uint256) public credit;
    mapping(address => ICallback) public callbacks;

    function deposit() public payable {
        credit[msg.sender] += msg.value;
    }

    function transfer(address to, uint256 amount) public {
        require(credit[msg.sender] >= amount);

        ICallback cb = callbacks[to];
        if (address(cb) != address(0)) {
            require(cb.transferred(msg.sender, to, amount));
        }
        cb = callbacks[msg.sender];
        if (address(cb) != address(0)) {
            require(cb.transferred(msg.sender, to, amount));
        }

        credit[msg.sender] -= amount;
        credit[to] += amount;
    }

    function withdraw(uint256 amount) public {
        require(credit[msg.sender] >= amount);

        ICallback cb = callbacks[msg.sender];
        if (address(cb) != address(0)) {
            require(cb.withdrawn(msg.sender, amount));
        }

        credit[msg.sender] -= amount;
        msg.sender.transfer(amount);
    }

    function queryCredit(address to) public view returns (uint256) {
        return credit[to];
    }

    function registerCallback(ICallback _cb) public {
        require(address(_cb) != msg.sender);
        callbacks[msg.sender] = _cb;
    }
}
