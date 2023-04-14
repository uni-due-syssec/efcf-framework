pragma solidity ^0.5.0;

// Original example from https://github.com/b-mueller/sabre#example-2-integer-precision-bug

contract FunWithNumbers {
    uint256 public constant tokensPerEth = 10;
    uint256 public constant weiPerEth = 1e18;
    mapping(address => uint256) public balances;

    function buyTokens() public payable {
        uint256 tokens = (msg.value / weiPerEth) * tokensPerEth; // convert wei to eth, then multiply by token rate
        balances[msg.sender] += tokens;
    }

    function sellTokens(uint256 tokens) public {
        require(balances[msg.sender] >= tokens);
        uint256 eth = tokens / tokensPerEth;
        balances[msg.sender] -= tokens;
        msg.sender.transfer(eth * weiPerEth);
    }
}

contract VerifyFunWithNumbers is FunWithNumbers {
    uint256 contract_balance_old;

    constructor() public {
        contract_balance_old = address(this).balance;
    }

    event AssertionFailed(string message);

    modifier checkInvariants() {
        uint256 sender_balance_old = balances[msg.sender];

        _;

        if (
            address(this).balance > contract_balance_old &&
            balances[msg.sender] <= sender_balance_old
        ) {
            emit AssertionFailed(
                "Invariant violation: Sender token balance must increase when contract account balance increases"
            );
        }
        if (
            balances[msg.sender] > sender_balance_old &&
            contract_balance_old >= address(this).balance
        ) {
            emit AssertionFailed(
                "Invariant violation: Contract account balance must increase when sender token balance increases"
            );
        }
        if (
            address(this).balance < contract_balance_old &&
            balances[msg.sender] >= sender_balance_old
        ) {
            emit AssertionFailed(
                "Invariant violation: Sender token balance must decrease when contract account balance decreases"
            );
        }
        if (
            balances[msg.sender] < sender_balance_old &&
            address(this).balance >= contract_balance_old
        ) {
            emit AssertionFailed(
                "Invariant violation: Contract account balance must decrease when sender token balance decreases"
            );
        }

        contract_balance_old = address(this).balance;
    }

    function buyTokens() public payable checkInvariants {
        super.buyTokens();
    }

    function sellTokens(uint256 tokens) public checkInvariants {
        super.sellTokens(tokens);
    }
}
