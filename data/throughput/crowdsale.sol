pragma solidity ^0.7;

contract crowdsale {
    uint256 goal = 10000 * 10**18;
    uint256 raised = 0;
    uint256 closeTime;
    address payable owner;
    mapping(address => uint256) deposits;
    uint256 phase; // 0: active, 1: success, 2: refund

    constructor() {
        closeTime = block.timestamp + 30 days;
        owner = msg.sender;
    }

    function invest() public payable {
        require(phase == 0 && raised < goal);
        deposits[msg.sender] += msg.value;
        raised += msg.value;
    }

    function setPhase(uint256 newPhase) public {
        require(
            (newPhase == 1 && raised >= goal) ||
                (newPhase == 2 && raised < goal && block.timestamp >= closeTime)
        );
        phase = newPhase;
    }

    function setOwner(address payable newOwner) public {
        require(msg.sender == owner);
        owner = newOwner;
    }

    function withdraw() public {
        require(phase == 1);
        owner.transfer(raised);
    }

    function refund() public {
        require(phase == 2);
        msg.sender.transfer(deposits[msg.sender]);
        deposits[msg.sender] = 0;
    }

    function echidna_nop() public view returns (bool) {
        return true;
    }
}
