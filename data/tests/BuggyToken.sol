// original source: https://github.com/uni-due-syssec/eth-reentrancy-attack-patterns

pragma solidity 0.7.6;

contract BuggyToken {
    // This contract keeps track of two balances for it's users. A user can
    // send ether to this contract and exchange ether for tokens and vice
    // versa, given a varying exchange rate (currentRate).
    mapping(address => uint256) tokenBalance;
    mapping(address => uint256) etherBalance;
    uint256 constant currentRate = 2;

    function getTokenCountFor(address x) public view returns (uint256) {
        return tokenBalance[x];
    }

    function getEtherCountFor(address x) public view returns (uint256) {
        return etherBalance[x];
    }

    function getTokenCount() public view returns (uint256) {
        return tokenBalance[msg.sender];
    }

    function depositEther() public payable {
        if (msg.value > 0) {
            etherBalance[msg.sender] += msg.value;
        }
    }

    function exchangeTokens(uint256 amount) public {
        if (tokenBalance[msg.sender] >= amount) {
            uint256 etherAmount = amount * currentRate;
            etherBalance[msg.sender] += etherAmount;
            tokenBalance[msg.sender] -= amount;
        }
    }

    function exchangeEther(uint256 amount) public payable {
        etherBalance[msg.sender] += msg.value;
        if (etherBalance[msg.sender] >= amount) {
            uint256 tokenAmount = amount / currentRate;
            etherBalance[msg.sender] -= amount;
            tokenBalance[msg.sender] += tokenAmount;
        }
    }

    function transferToken(address to, uint256 amount) public {
        if (tokenBalance[msg.sender] >= amount) {
            tokenBalance[to] += amount;
            tokenBalance[msg.sender] -= amount;
        }
    }

    function exchangeAndWithdrawToken(uint256 amount) public {
        if (tokenBalance[msg.sender] >= amount) {
            // BUG: etherAmount is computed based on the full tokenBalance and
            // not only on amount
            uint256 etherAmount = tokenBalance[msg.sender] * currentRate;
            tokenBalance[msg.sender] -= amount;

            msg.sender.transfer(etherAmount);
        }
    }

    function withdrawAll() public {
        uint256 etherAmount = etherBalance[msg.sender];
        uint256 tokenAmount = tokenBalance[msg.sender];
        if (etherAmount > 0 && tokenAmount > 0) {
            uint256 e = etherAmount + (tokenAmount * currentRate);

            etherBalance[msg.sender] = 0;
            tokenBalance[msg.sender] = 0;

            msg.sender.transfer(e);
        }
    }
}
