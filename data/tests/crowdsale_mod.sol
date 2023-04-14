pragma solidity 0.7.6;

// the problem with the original crowdsale contract is that it is *only*
// exploitable if there are other users that call the `invest()` function. In
// EF/CF we do not simulate other benign contracts. As such, there is not
// attack here, since we only get back our own money... However, if we change
// the contract to not use the `raised` variable, but `address(this).balance`,
// EF/CF will pick up the bug.

contract CrowdsaleMod {
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
        // require(msg.sender == owner);
        owner = newOwner;
    }

    function withdraw() public {
        require(phase == 1);
        // PATCH: this change makes EF/CF detect the bug.
        /* owner.transfer(raised); */
        owner.transfer(address(this).balance);
    }

    function refund() public {
        require(phase == 2);
        msg.sender.transfer(deposits[msg.sender]);
        deposits[msg.sender] = 0;
    }

    function echidna_oracle() public view returns (bool) {
        return !(owner == msg.sender && phase == 1);
    }
}
