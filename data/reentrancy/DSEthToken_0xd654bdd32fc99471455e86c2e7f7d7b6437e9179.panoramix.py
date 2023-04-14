#
#  Panoramix v4 Oct 2019 
#  Decompiled source of 0xd654bDD32FC99471455e86C2E7f7D7b6437e9179
# 
#  Let's make the world open source 
# 
#
#  I failed with these: 
#  - _fallback()
#  All the rest is below.
#

const totalSupply = eth.balance(this.address)

def storage:
  balanceOf is mapping of uint256 at storage 0
  allowance is mapping of uint256 at storage 1

def balanceOf(address _owner) payable: 
  return balanceOf[addr(_owner)]

def allowance(address _owner, address _spender) payable: 
  return allowance[addr(_owner)][addr(_spender)]

#
#  Regular functions
#

def deposit() payable: 
  balanceOf[caller] += call.value
  log Deposit(
        address owner=call.value,
        uint256 amount=caller)
  return 1

def approve(address _spender, uint256 _value) payable: 
  allowance[caller][addr(_spender)] = _value
  log Approval(
        address owner=_value,
        address spender=caller,
        uint256 value=_spender)
  return 1

def withdraw(uint256 _amount) payable: 
  if balanceOf[caller] < _amount:
      return 0
  call caller with:
     value _amount wei
       gas gas_remaining - 34050 wei
  if not ext_call.success:
      return 0
  balanceOf[caller] -= _amount
  log Withdrawal(
        address owner=_amount,
        uint256 amount=caller)
  return 1

def transfer(address _to, uint256 _value) payable: 
  require balanceOf[caller] >= _value
  require balanceOf[addr(_to)] + _value >= balanceOf[addr(_to)]
  balanceOf[caller] -= _value
  balanceOf[addr(_to)] += _value
  log Transfer(
        address from=_value,
        address to=caller,
        uint256 value=_to)
  return 1

def transferFrom(address _from, address _to, uint256 _value) payable: 
  require balanceOf[addr(_from)] >= _value
  require allowance[addr(_from)][caller] >= _value
  require balanceOf[addr(_to)] + _value >= balanceOf[addr(_to)]
  allowance[addr(_from)][caller] -= _value
  balanceOf[addr(_from)] -= _value
  balanceOf[addr(_to)] += _value
  log Transfer(
        address from=_value,
        address to=_from,
        uint256 value=_to)
  return 1


