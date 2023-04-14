pragma solidity 0.7.6;

contract FiftyYearsChallenge {
    struct Contribution {
        uint256 amount;
        uint256 unlockTimestamp;
    }
    Contribution[] queue;
    uint256 head;

    address owner;

    constructor() payable {}

    function startChallenge(address player) public payable {
        require(owner == address(0));

        owner = player;
        queue.push(
            Contribution(address(this).balance, block.timestamp + 18300 days)
        );
    }

    function isComplete() public view returns (bool) {
        return address(this).balance == 0;
    }

    function upsert(uint256 index, uint256 timestamp) public payable {
        require(msg.sender == owner);

        if (index >= head && index < queue.length) {
            // Update existing contribution amount without updating timestamp.
            Contribution storage contribution = queue[index];
            contribution.amount += msg.value;
        } else {
            // Append a new contribution. Require that each contribution unlock
            // at least 1 day after the previous one.
            require(
                timestamp >= queue[queue.length - 1].unlockTimestamp + 1 days
            );

            queue.push(Contribution(msg.value, timestamp));
        }
    }

    function withdraw(uint256 index) public {
        require(msg.sender == owner);
        require(block.timestamp >= queue[index].unlockTimestamp);

        // Withdraw this and any earlier contributions.
        uint256 total = 0;
        for (uint256 i = head; i <= index; i++) {
            total += queue[i].amount;

            // Reclaim storage.
            delete queue[i];
        }

        // Move the head of the queue forward so we don't have to loop over
        // already-withdrawn contributions.
        head = index + 1;

        msg.sender.transfer(total);
    }
}
