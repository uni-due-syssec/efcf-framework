/*
 * This contract requires to generate a reentrant test case that traverses deep
 * into the call chain, i.e., it requires multiple reentrant transactions from
 * different contract addresses (to bypass the locking mechanism).
 * Additionally, it must execute a wider call tree
 *
 * A1
 *  |-> entry()
 *   |-> A1
 *    |-> lvl1_f1()
 *     |-> A1
 *      |-> lvl2_f1()
 *      |-> lvl2_f1()
 *      |-> lvl2_f1()
 *    |-> A2
 *     |-> lvl1_f2()
 *      |-> A3
 *       |-> lvl2_f2()
 *        |-> A3
 *         |-> A4
 *          |-> trigger()
 *
 *
 */

pragma solidity 0.7.6;

contract ReentrancyDeepCrossFunctionMultiAttackerLevels {
    event EntryReached();
    event LevelReached(uint256 level, uint256 func);

    mapping(address => bool) locks;
    uint256 lvl_entry = 0;

    uint256 lvl1_barrier = 0;
    uint256 lvl2_barrier = 0;

    uint256 lvl1_key1 = 0;
    uint256 lvl1_key2 = 0;

    uint256 lvl2_key1 = 0;
    uint256 lvl2_key2 = 0;

    mapping(address => uint256) public balances;

    function deposit() public payable {
        balances[msg.sender] += msg.value;
    }

    modifier locked() {
        require(locks[msg.sender] == false);
        locks[msg.sender] = true;
        _;
        locks[msg.sender] = false;
    }

    function entry() public locked {
        emit EntryReached();
        lvl_entry = 1;
        msg.sender.call("");
        lvl_entry = 0;
    }

    // toggles lvl1_key1
    function lvl1_f1() public {
        // must be called reentrant from entry
        require(lvl_entry == 1);
        // must not be called after lvl2_f1
        require(lvl1_key2 == 0);
        // must not be reentered
        require(lvl1_barrier == 0);

        emit LevelReached(1, 1);

        lvl1_key1 ^= 1;
        lvl1_barrier = 1;
        msg.sender.call("");
        lvl1_barrier = 0;
    }

    function lvl2_f1() public {
        // must be called reentrant from entry
        require(lvl_entry == 1);
        // must be called reentrant from lvl1_f1
        require(lvl1_barrier == 1);
        // must not be called reentrant from a lvl2 function
        require(lvl2_barrier == 0);

        emit LevelReached(2, 1);

        lvl2_key1 += lvl1_key1;
        lvl2_barrier = 1;
        msg.sender.call("");
        lvl2_barrier = 0;
    }

    function lvl1_f2() public locked {
        // must be called reentrant from entry
        require(lvl_entry == 1);
        // must not be reentered
        require(lvl1_barrier == 0);
        require(lvl1_key2 == 0);

        emit LevelReached(1, 2);

        lvl1_key2 = 1;
        msg.sender.call("");
        lvl1_key2 = 0;
    }

    function lvl2_f2() public locked {
        // must be called reentrant from entry
        require(lvl_entry == 1);
        require(lvl2_barrier == 0);
        require(lvl2_key2 == 0);

        emit LevelReached(2, 2);

        lvl2_key2 = 1;
        msg.sender.call("");
        lvl2_key2 = 0;
    }

    function trigger() public locked {
        // force the execution tree as described in the comment on top
        require(lvl_entry == 1);
        require(lvl1_key1 == 1);
        require(lvl1_key2 == 1);
        require(lvl2_key1 == 3);
        require(lvl2_key2 == 1);
        msg.sender.transfer(address(this).balance);
        /* selfdestruct(payable(msg.sender)); */
    }
}
