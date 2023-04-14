pragma solidity 0.7.6;

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

contract VulnBankBuggyLockHard {
    using SafeMath for uint256;

    mapping(address => uint256) private userBalances;
    mapping(address => bool) private disableWithdraw;
    mapping(address => mapping(address => uint256)) private allowance;

    modifier withdrawAllowed {
        require(disableWithdraw[msg.sender] == false);
        _;
    }

    function getBalance(address a) public view returns (uint256) {
        return userBalances[a];
    }

    function deposit() public payable {
        if (msg.value > 0) {
            userBalances[msg.sender] = userBalances[msg.sender].add(msg.value);
        }
    }

    function addAllowance(address other, uint256 amount) public {
        allowance[msg.sender][other] = allowance[msg.sender][other].add(amount);
    }

    // The withdrawBalance function call is making it possible to reenter this
    // contract. However, all the functions that modify the balance are
    // checking whether a lock was set using the withdrawAllowed modifier. So
    // the attacker cannot reenter the transfer or transferFrom function
    // anymore.
    //
    // However, the attacker can collude with a second account, e.g., call into
    // another attacker contract, that then reenters into the transferFrom
    // function. Since the second account has not yet called the withdraw
    // function it is still allowed to enter the contract since this locking
    // mechanism has not locked the second contract.

    // the transferFrom style function is quite common in Token-like contracts
    // essentially you can give another contract permission to withdraw a
    // certain amount from your own account.
    function transferFrom(address from, uint256 amount) public withdrawAllowed
    {
        require(userBalances[from] >= amount);
        require(allowance[from][msg.sender] >= amount);
        
        userBalances[from] = userBalances[from].sub(amount);
        allowance[from][msg.sender] = allowance[from][msg.sender].sub(amount);
        userBalances[msg.sender] = userBalances[msg.sender].add(amount);
    }

    function transfer(address to, uint256 amount) public withdrawAllowed {
        require(userBalances[msg.sender] >= amount); 
        userBalances[msg.sender] = userBalances[msg.sender].sub(amount);
        userBalances[to] = userBalances[to].add(amount);
    }

    function withdrawBalance() public withdrawAllowed {

        uint256 amountToWithdraw = userBalances[msg.sender];

        if (amountToWithdraw > 0) {
            disableWithdraw[msg.sender] = true;
            msg.sender.call{value: amountToWithdraw}("");
            disableWithdraw[msg.sender] = false;

            userBalances[msg.sender] = 0;
        }
    }
}
