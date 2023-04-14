pragma solidity 0.7.6;

contract TimeStamp {
    // keeps time frames for vote period
    struct VotePeriod {
        uint256 start;
        uint256 end;
    }

    // vote period
    VotePeriod votePeriod;

    //
    mapping(address => uint256) votes;
    mapping(address => bool) voted;
    address currentLeader;

    constructor() payable {
        // inspired by project kudos example from ILF paper.
        votePeriod = VotePeriod(
            1479996000, // GMT: 24-Nov-2016 14:00
            1482415200 // GMT: 22-Dec-2016 14:00
        );

        currentLeader = msg.sender;
    }

    modifier inVotePeriod() {
        require(block.timestamp >= votePeriod.start);
        require(block.timestamp <= votePeriod.end);
        _;
    }

    modifier afterVotePeriod() {
        require(block.timestamp > votePeriod.end);
        _;
    }

    function vote(address _for) public payable inVotePeriod {
        // no double votes!
        require(!voted[msg.sender]);
        // require some participation in the prize pool
        require(msg.value > 0);
        // don't allow self-votes
        require(msg.sender != _for);
        voted[msg.sender] = true;
        votes[_for] += 1;

        if (votes[_for] > votes[currentLeader]) {
            currentLeader = _for;
        }
    }

    function cashout() public afterVotePeriod {
        require(currentLeader != address(0));
        require(msg.sender == currentLeader);
        selfdestruct(msg.sender);
    }
}
