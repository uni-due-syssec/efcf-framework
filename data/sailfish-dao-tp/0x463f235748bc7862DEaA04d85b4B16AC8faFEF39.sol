pragma solidity ^0.4.19;

contract PrivateBank {
    mapping(address => uint256) balances;

    function GetBal() public returns (uint256) {
        return balances[msg.sender];
    }

    uint256 public MinDeposit = 1 ether;

    Log TransferLog;

    function PrivateBank(address _lib) {
        TransferLog = Log(_lib);
    }

    function Deposit() public payable {
        if (msg.value >= MinDeposit) {
            balances[msg.sender] += msg.value;
            TransferLog.AddMessage(msg.sender, msg.value, "Deposit");
        }
    }

    function CashOut(uint256 _am) {
        if (_am <= balances[msg.sender]) {
            if (msg.sender.call.value(_am)()) {
                balances[msg.sender] -= _am;
                TransferLog.AddMessage(msg.sender, _am, "CashOut");
            }
        }
    }

    function() public payable {}
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
