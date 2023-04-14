// Adapted from Figure 2 of the paper "SAILFISH: Vetting Smart Contract
// State-Inconsistency Bugs in Seconds" by Bose et al.

pragma solidity 0.7.6;

contract reentrancy_splits {
    mapping(uint256 => uint256) deposits;
    mapping(uint256 => uint256) splits;
    mapping(uint256 => address payable[2]) payee;

    function newSplit(uint256 id) public payable {
        deposits[id] += msg.value;
        splits[id] = 100;
        payee[id][0] = msg.sender;
        payee[id][1] = msg.sender;
    }

    function deposit(uint256 id) public payable {
        require(msg.value > 0);
        require(id > 0x10000);
        deposits[id] += msg.value;
    }

    function registerPayee(
        uint256 id,
        address payable a,
        address payable b
    ) public {
        payee[id][0] = a;
        payee[id][1] = b;
    }

    // [Step 1]: Set split of ’a’ (id = 0) to 100(%)
    // [Step 4]: Set split of ’a’ (id = 0) to 0(%)
    function updateSplit(uint256 id, uint256 split) public {
        require(split <= 100);
        splits[id] = split;
    }

    function splitFunds(uint256 id) public {
        address payable a = payee[0][id];
        address payable b = payee[1][id];
        uint256 depo = deposits[id];
        deposits[id] = 0;

        // [Step 2]: Transfer 100% fund to ’a’
        // [Step 3]: Reenter updateSplit
        (bool res, bytes memory _r) = a.call{value: (depo * splits[id]) / 100}(
            ""
        );
        require(res);

        // [Step 5]: Transfer 100% fund to ’b’
        b.transfer((depo * (100 - splits[id])) / 100);
    }
}
