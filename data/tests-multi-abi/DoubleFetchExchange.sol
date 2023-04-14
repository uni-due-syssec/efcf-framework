// this is an incredibly tricky thing to detect:
//
// 1. The attacker buys some tokens via the Exchange contract
//    [Attacker, Exchange.buy]
// 2. the attacker sells the tokens again
//    [Attacker, Exchange.sell]
// 3. the contract calls into the attacker
//    [Attacker, Exchange.sell, Attacker]
// 4. the attacker enters the token contracts to transfer the tokens
//    [Attacker, Exchange.sell, Attacker, Token.transfer]
// 5. the attacker returns.
//    [Attacker2, Exchange.sell]

pragma solidity ^0.7.6;

/**
 * @title SafeMath
 * @dev Math operations with safety checks that throw on error
 */
library SafeMath {
    /**
     * @dev Multiplies two numbers, throws on overflow.
     */
    function mul(uint256 a, uint256 b) internal pure returns (uint256 c) {
        if (a == 0) {
            return 0;
        }
        c = a * b;
        assert(c / a == b);
        return c;
    }

    /**
     * @dev Integer division of two numbers, truncating the quotient.
     */
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        // assert(b > 0); // Solidity automatically throws when dividing by 0
        // uint256 c = a / b;
        // assert(a == b * c + a % b); // There is no case in which this doesn't hold
        return a / b;
    }

    /**
     * @dev Subtracts two numbers, throws on overflow (i.e. if subtrahend is greater than minuend).
     */
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        assert(b <= a);
        return a - b;
    }

    /**
     * @dev Adds two numbers, throws on overflow.
     */
    function add(uint256 a, uint256 b) internal pure returns (uint256 c) {
        c = a + b;
        assert(c >= a);
        return c;
    }
}

contract Token {
    using SafeMath for uint256;

    address owner = msg.sender;

    mapping(address => uint256) private balances;

    function get(address _who) public view returns (uint256) {
        return balances[_who];
    }

    function set(address _who, uint256 _what) public {
        require(msg.sender == owner);
        balances[_who] = _what;
    }

    function transfer(address _to, uint256 _amount) public {
        require(balances[msg.sender] >= _amount);
        balances[msg.sender] = balances[msg.sender].sub(_amount);
        balances[_to] = balances[_to].add(_amount);
    }
}

contract DoubleFetchExchange {
    Token token;
    uint256 rate;
    using SafeMath for uint256;

    constructor(Token _token) {
        token = _token;
        rate = 2;
    }

    uint256 __re_lock = 0;
    modifier nonReentrant() {
        require(__re_lock == 0);
        __re_lock = 1;
        _;
        __re_lock = 0;
    }

    function getTokenBalance(address a) public view returns (uint256) {
        return token.get(a);
    }

    function getEtherBalance(address a) public view returns (uint256) {
        return token.get(a) * rate;
    }

    function buy() public payable {
        require(msg.value > 0);
        uint256 amount = msg.value / rate;
        amount = amount.add(token.get(msg.sender));
        token.set(msg.sender, amount);
    }

    function sell(uint256 _amount) public nonReentrant {
        uint256 tokens = token.get(msg.sender);
        require(tokens >= _amount);
        uint256 ether_amount = _amount.mul(rate);
        (bool r, bytes memory _wut) = msg.sender.call{value: ether_amount}("");
        require(r);
        token.set(msg.sender, tokens.sub(_amount));
    }
}
