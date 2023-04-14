/*
 * This contract requires to generate a reentrant test case that traverses deep
 * into the call chain, i.e., it requires multiple reentrant transactions from
 * different contract addresses (to bypass the locking mechanism).
 *
 * A1
 *  |-> f1()
 *   |-> A1
 *    |-> A2
 *     |-> f2()
 *      |-> A2
 *       |-> A3
 *         |-> f3()
 *          |-> A3
 *           |-> A4
 *            |-> f4()
 *             |-> A4
 *              |-> trigger()
 *
 *
 */

pragma solidity 0.7.6;

contract ReentrancyDeepCrossFunctionMultiAttacker {
    mapping(address => bool) locks;
    uint256 a = 0;
    uint256 b = 0;
    uint256 c = 0;
    uint256 d = 0;

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

    function f1() public locked {
        a = 1;
        msg.sender.call("a");
        a = 0;
    }

    function f2() public locked {
        require(a == 1);
        b = 1;
        msg.sender.call("b");
        b = 0;
    }

    function f3() public locked {
        require(b == 1);
        c = 1;
        msg.sender.call("c");
        c = 0;
    }

    function f4() public locked {
        require(c == 1);
        d = 1;
        msg.sender.call("d");
        d = 0;
    }

    function trigger() public {
        require(a == 1);
        require(b == 1);
        require(c == 1);
        require(d == 1);
        msg.sender.transfer(address(this).balance);
    }
}
