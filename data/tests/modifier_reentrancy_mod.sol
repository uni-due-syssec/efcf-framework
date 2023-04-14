// modified version from https://swcregistry.io/docs/SWC-107#modifier-reentrancysol

pragma solidity 0.7.6;

abstract contract Bank {
    function supportsToken() external virtual returns (bytes32);
}

contract ModifierReentrancyMod {
    mapping(address => uint256) public tokenBalance;
    string constant name = "Nu Token";
    bytes32 constant name_hash = keccak256(abi.encodePacked(name));
    Bank bank;
    uint256 constant initial_drop = 20;
    uint256 constant rate = 1000;

    // If a contract has a zero balance and supports the token give them some token
    function airDrop() public hasNoBalance supportsToken {
        // the reentrancy can be xploited here due to the ordering of the
        // modifier. The supportsToken modifier will trigger an external call,
        // after the hasNoBalance has ensured
        tokenBalance[msg.sender] += initial_drop;
    }

    //Checks that the contract responds the way we want
    modifier supportsToken() {
        require(address(bank) != address(0));
        // this check here is the main challenge to the fuzzer, but should be
        // easily solvable with something redqueen-like (input-to-state)
        require(name_hash == bank.supportsToken());
        _;
    }

    //Checks that the caller has a zero balance
    modifier hasNoBalance() {
        require(tokenBalance[msg.sender] == 0);
        _;
    }

    // somewhat stupid function that allows the fuzzer to set the bank address to
    // an "attacker contract". Otherwise reentrancy is not exploitable.
    function registerBank(Bank _bank) public {
        bank = _bank;
    }

    // these function are necessary s.t., the ether bug oracle can be
    // triggered
    receive() external payable {}

    function withdrawEther() public payable {
        uint256 balance = tokenBalance[msg.sender];
        // airdrop gives us ether for nothing; so we need to add this here s.t.,
        // the ether oracle doesn't report without triggering the reentrancy
        require(balance > initial_drop);
        tokenBalance[msg.sender] = 0;
        msg.sender.transfer(balance * rate);
    }
}
