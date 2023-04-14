// Example adapted from the paper "Compositional Security for Reentrant
// Applications" by Cecchetti et al.
//
// This is the vulnerable Uniswap example.

pragma solidity 0.7.6;

interface Holder {
    function alertSend(address x, uint amount) external; 
    function alertReceive(address x, uint amount) external; 
}

contract Token {
  mapping(address => uint) balances;
  mapping(address => bool) isAdmin;

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
}

contract Uniswap {
    Token tX = new Token();
    Token tY = new Token();

    function exchangeXForY(uint xSold) public returns(uint) {
        address buyer = msg.sender;
        uint tXSold = xSold;
        address _this = address(this);

        uint prod = getBal(tX, _this) * getBal(tY, _this);
        uint yKept = prod / (getBal(tX, _this) + tXSold);
        uint yBought = getBal(tY, _this) - yKept;

        require(tX.transfer(buyer, _this, tXSold));
        require(tY.transfer(_this, buyer, yBought));
        return yBought;
    }

    function getBal(Token token, address k) public view returns(uint) {
        return token.getBal(k);
    } 
}
