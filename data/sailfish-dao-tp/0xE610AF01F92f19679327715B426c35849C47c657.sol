pragma solidity ^0.4.19;

contract PIGGY_BANK {
    mapping(address => uint256) public Accounts;

    uint256 public MinSum = 1 ether;

    Log LogFile;

    uint256 putBlock;

    function PIGGY_BANK(address _log) public {
        LogFile = Log(_log);
    }

    function Put(address to) public payable {
        Accounts[to] += msg.value;
        LogFile.AddMessage(msg.sender, msg.value, "Put");
        putBlock = block.number;
    }

    function Collect(uint256 _am) public payable {
        if (
            Accounts[msg.sender] >= MinSum &&
            _am <= Accounts[msg.sender] &&
            block.number > putBlock
        ) {
            if (msg.sender.call.value(_am)()) {
                Accounts[msg.sender] -= _am;
                LogFile.AddMessage(msg.sender, _am, "Collect");
            }
        }
    }

    function() public payable {
        Put(msg.sender);
    }
}

contract Log {
    struct Message {
        address Sender;
        string Data;
        uint256 Val;
        uint256 Time;
    }

    Message[] public History;

    Message LastMsg;

    function AddMessage(
        address _adr,
        uint256 _val,
        string _data
    ) public {
        LastMsg.Sender = _adr;
        LastMsg.Time = now;
        LastMsg.Val = _val;
        LastMsg.Data = _data;
        History.push(LastMsg);
    }
}
