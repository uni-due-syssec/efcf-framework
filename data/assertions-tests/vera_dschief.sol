pragma solidity ^0.7.6;

contract SimpleDSChief {
    mapping(bytes32 => address) public slates;
    mapping(address => bytes32) public votes;
    mapping(address => uint256) public approvals;
    mapping(address => uint256) public deposits;

    function lock(uint256 wad) public {
        deposits[msg.sender] = add(deposits[msg.sender], wad);
        addWeight(wad, votes[msg.sender]);
    }

    function free(uint256 wad) public {
        deposits[msg.sender] = sub(deposits[msg.sender], wad);
        subWeight(wad, votes[msg.sender]);
    }

    function voteYays(address yay) public returns (bytes32) {
        bytes32 slate = etch(yay);
        voteSlate(slate);

        return slate;
    }

    function etch(address yay) public returns (bytes32 slate) {
        bytes32 hash = keccak256(abi.encodePacked(yay));

        slates[hash] = yay;

        return hash;
    }

    function voteSlate(bytes32 slate) public {
        uint256 weight = deposits[msg.sender];
        subWeight(weight, votes[msg.sender]);
        votes[msg.sender] = slate;
        addWeight(weight, votes[msg.sender]);
    }

    function addWeight(uint256 weight, bytes32 slate) internal {
        address yay = slates[slate];
        approvals[yay] = add(approvals[yay], weight);
    }

    function subWeight(uint256 weight, bytes32 slate) internal {
        address yay = slates[slate];
        approvals[yay] = sub(approvals[yay], weight);
    }

    function add(uint256 x, uint256 y) internal pure returns (uint256 z) {
        require((z = x + y) >= x);
    }

    function sub(uint256 x, uint256 y) internal pure returns (uint256 z) {
        require((z = x - y) <= x);
    }

    event AssertionFailed();

    function checkAnInvariant() public {
        bytes32 senderSlate = votes[msg.sender];
        address option = slates[senderSlate];
        uint256 senderDeposit = deposits[msg.sender];

        if (!(approvals[option] >= senderDeposit)) {
            emit AssertionFailed();
        }
    }
}
