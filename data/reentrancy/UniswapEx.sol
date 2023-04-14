// Example adapted from the paper "Compositional Security for Reentrant
// Applications" by Cecchetti et al.
//
// This is the vulnerable Uniswap example, slightly adapted such that it works
// also in a dynamic analysis context, i.e.,
// * airdrop() function to get some initial tokens
// * swap Ether with Token and not two tokens

pragma solidity 0.7.6;

interface Holder {
    function alertSend(address x, uint amount) external; 
    function alertReceive(address x, uint amount) external; 
}

contract Token {
  mapping(address => uint) balances;
  mapping(address => bool) isAdmin;

  constructor() {
      isAdmin[msg.sender] = true;
  }

  function transfer(address frm, address to, uint amount) public returns (bool) {
      address sender = msg.sender;
      if (frm != sender && isAdmin[frm] != true) {
            return false;
      }
      
      if (balances[frm] < amount) {
      	  return false;
      }
      
      balances[frm] = balances[frm] - amount;
      balances[to] = balances[to] + amount;

      Holder _frm = Holder(frm);
      _frm.alertSend(to, amount);

      Holder _to = Holder(to);
      _to.alertReceive(frm, amount);

      return true;
  }

  function getBal(address user) public view returns(uint) {
      return balances[user];
  }

  function airdrop(address who) public {
      if (isAdmin[msg.sender]) {
          balances[who] = 100000;
      }
  }
}

contract UniswapEx is Holder {
    Token tX = new Token();
    uint eth_balance = 0;
    
    function getBal(Token token, address k) public view returns(uint) {
        return token.getBal(k);
    } 

    function exchangeTokenForEther(uint sold) public returns(uint) {
        address payable buyer = payable(msg.sender);
        address _this = address(this);
        require(getBal(tX, msg.sender) >= sold);

        uint tokenBalance = getBal(tX, _this);
        uint prod = tokenBalance * eth_balance;
        uint kept = prod / (tokenBalance + sold);
        uint bought = eth_balance - kept;

        // and transfer ether to user
        buyer.transfer(bought);
        // transfer user tokens to uniswap
        require(tX.transfer(buyer, _this, sold));
        return bought;
    }

    function exchangeEtherForToken() public payable returns(uint) {
        address payable buyer = payable(msg.sender);
        address _this = address(this);

        uint tokenBalance = getBal(tX, _this);
        uint prod = tokenBalance * eth_balance;
        uint kept = prod / (eth_balance + msg.value);
        uint bought = tokenBalance - kept;

        // and transfer tokens to buyer
        require(tX.transfer(_this, buyer, bought));
        // and transfer ether to uniswap
        eth_balance += msg.value;
        return bought;
    }


    bool dropped = false;
    function airdrop() public {
        require(!dropped && tX.getBal(address(this)) == 0);
        tX.airdrop(address(this));
        dropped = true;
    }

    constructor() payable {}
    event UniAlertSend(address, uint);
    function alertSend(address x, uint amount) external override {
        emit UniAlertSend(x, amount);
    } 
    event UniAlertReceive(address, uint);
    function alertReceive(address x, uint amount) external override {
        emit UniAlertReceive(x, amount);
    }
}
