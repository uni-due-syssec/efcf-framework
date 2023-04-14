# Sailfish Findings Analysis 


EF/CF Results; two lines with `True` means both an attack was found with both mainnet state export and source-code only fuzzing.

```
0x03C18D649E743Ee0b09f28a81D33575F03af9826 => finding? =>  False 20:00.07
0x1257F00e0333d7c9F9c87aBF1DCE6e373A6492F6 => finding? =>  False 20:00.04
0x1257F00e0333d7c9F9c87aBF1DCE6e373A6492F6 => finding? =>  False 20:00.05
0x2AD1cE69Ea75a79F6070394a1b712dB14965e3b4 => finding? =>  False 20:00.03
0x2D52D1517f47e1AB7be6377a1f11fbd2C49978dB => finding? =>  False 20:00.15
0x2D52D1517f47e1AB7be6377a1f11fbd2C49978dB => finding? =>  False 20:00.13
0x3B1c6004e43bF49c521eB382dEc02e6c3fF5272a => finding? =>  False 20:00.08
0x3aD4FAD3CE0509475E5B4f597C53cbA38873cC46 => finding? =>  False 20:00.13
0x3aD4FAD3CE0509475E5B4f597C53cbA38873cC46 => finding? =>  False 20:00.07
0x463f235748bc7862DEaA04d85b4B16AC8faFEF39 => finding? =>  True 12:23.96
0x463f235748bc7862DEaA04d85b4B16AC8faFEF39 => finding? =>  False 20:00.10
0x5aB2e3F693E6961beea08c1db8A3602FceA6B36F => finding? =>  False 20:00.07
0x69640F28B6FE4aE4674EFDBe21Aa15d048bb914B => finding? =>  True 0:03.10
0x69640F28B6FE4aE4674EFDBe21Aa15d048bb914B => finding? =>  True 0:02.57
0x6C1BCB34142BFfD35f57dB626E0aC427AF616a4D => finding? =>  False 20:00.07
0x6C1BCB34142BFfD35f57dB626E0aC427AF616a4D => finding? =>  False 20:00.12
0x7b203459EB87Fbf70ca42624B4304dc24EDE9c50 => finding? =>  False 20:00.10
0x8B168e46281e72d410717b27A6ca97Bf9F301173 => finding? =>  False 20:00.05
0xA395480A4A90c7066c8ddB5db83E2718E750641C => finding? =>  False 20:00.04
0xA395480A4A90c7066c8ddB5db83E2718E750641C => finding? =>  True 0:48.88
0xBd10c70e94aCA5c0b9Eb434A62f2D8444Ec0649D => finding? =>  False 20:00.13
0xE610AF01F92f19679327715B426c35849C47c657 => finding? =>  False 20:00.08
0xE610AF01F92f19679327715B426c35849C47c657 => finding? =>  False 20:00.13
0xEf86dB910c71FfA3C80233Bc9108Dc51Ad1E008A => finding? =>  False 20:00.11
0xaa12936a79848938770bDBC5da0d49Fe986678cc => finding? =>  False 20:00.05
0xaa12936a79848938770bDBC5da0d49Fe986678cc => finding? =>  True 0:02.78
0xc477042db387DD59C038Ca4b829a07964b674347 => finding? =>  False 20:00.11
0xc477042db387DD59C038Ca4b829a07964b674347 => finding? =>  False 20:00.06
0xcc1A13B76270A20A78F3beF434BDEB4a5eeC6a31 => finding? =>  False 20:00.11
0xd022969da8A1aCe11E2974b3e7EE476c3f9F99c6 => finding? =>  False 20:00.07
0xd022969da8A1aCe11E2974b3e7EE476c3f9F99c6 => finding? =>  True 0:10.35
0xd37e1d4509838d65873609158D1471627F697874 => finding? =>  False 20:00.06
0xf6e7ec5D6983FAFd6eB14C2A20C2dd354e09ce9B => finding? =>  True 1:10.73
0xf6e7ec5D6983FAFd6eB14C2A20C2dd354e09ce9B => finding? =>  True 0:31.78

```

**Analysis State: Sailfish TP; EF/CF no finding**

(using state-export fuzzing only)

* `0x03c18d649e743ee0b09f28a81d33575f03af9826`
* `0x1257f00e0333d7c9f9c87abf1dce6e373a6492f6`
* `0x2880f03f181ee0967a00bac5346574f58f91b615`
* `0x2ad1ce69ea75a79f6070394a1b712db14965e3b4`
* `0x2d52d1517f47e1ab7be6377a1f11fbd2c49978db`
* `0x3ad4fad3ce0509475e5b4f597c53cba38873cc46`
* `0x3b1c6004e43bf49c521eb382dec02e6c3ff5272a`
* `0x5ab2e3f693e6961beea08c1db8a3602fcea6b36f`
* `0x6c1bcb34142bffd35f57db626e0ac427af616a4d`
* `0x7b203459eb87fbf70ca42624b4304dc24ede9c50`
* `0x8b168e46281e72d410717b27a6ca97bf9f301173`
* `0xa395480a4a90c7066c8ddb5db83e2718e750641c`
* `0xaa12936a79848938770bdbc5da0d49fe986678cc`
* `0xb29405833e303db3193cf7c058e2c81ef027c6c8`
* `0xbd10c70e94aca5c0b9eb434a62f2d8444ec0649d`
* `0xc477042db387dd59c038ca4b829a07964b674347`
* `0xcc1a13b76270a20a78f3bef434bdeb4a5eec6a31`
* `0xd022969da8a1ace11e2974b3e7ee476c3f9f99c6`
* `0xd37e1d4509838d65873609158d1471627f697874`
* `0xdd1d5ce9f8e26a3f768b1c1e5c68db10a05d5fc0`
* `0xef86db910c71ffa3c80233bc9108dc51ad1e008a`
* `0xfe2a80103c9037354a04094972fc7ecab747272b`


**Analysis State: Sailfish TP, EF/CF finding**

* `0x463f235748bc7862DEaA04d85b4B16AC8faFEF39` "PrivateBank" true vuln, honeypot contract
* `0x69640F28B6FE4aE4674EFDBe21Aa15d048bb914B` "weeWho" true vuln, test contract, no exploit window
* `0xA395480A4A90c7066c8ddB5db83E2718E750641C` "PreSaleFund" true vuln; with exploit window
* `0xaa12936a79848938770bDBC5da0d49Fe986678cc` "PreSaleFund" true vuln; with exploit window
* `0xd022969da8A1aCe11E2974b3e7EE476c3f9F99c6` "PreSaleFund" true vuln; with small exploit window
* `0xf6e7ec5D6983FAFd6eB14C2A20C2dd354e09ce9B` "ABC" vulnerable to an access control bug, no reentrancy necessary.


##### 0x03c18d649e743ee0b09f28a81d33575f03af9826


`WeBetCrypto` contract
[etherscan](https://etherscan.io/address/0x03c18d649e743ee0b09f28a81d33575f03af9826#code)

According to sailfish the reentrancy is originating in the `transfer` function, which dispatches to one of three internal functions.
The `transferToSelf` and `transferToAddress` variants are safe, as they do not perform an external call. This is the remaining one:

```solidity
function addUser(address _user) internal {
    if (!isAdded[_user]) {
        users.push(_user);
        monthlyLimit[_user] = 5000000000000;
        isAdded[_user] = true;
    }
}

function transferToContract(
    address _to,
    uint256 _value,
    bytes _data
) internal returns (bool success) {
    balances[msg.sender] = safeSub(balances[msg.sender], _value);
    balances[_to] = balances[_to] + _value;
    WeBetCrypto rec = WeBetCrypto(_to);
    // external call
    rec.tokenFallback(msg.sender, _value, _data);
    // initializer 
    addUser(_to);
    Transfer(msg.sender, _to, _value);
    return true;
}
```

Here, only the user is initialized after the external call. The `balances` mapping is updated before the external call and uses the `safeSub` function to check for integer underflow.

This leaves the `addUser` internal function, which just sets default values. `isAdded[_user]` acts as a kind of mutex. So `transfer` -> `transfer` reentrancy cannot cause inconsistent state.

Sailfish identifies a potentially problematic reentrant path into another function:

```solidity
function transferFrom(
    address _from,
    address _to,
    uint256 _value
) external requireThaw userNotPlaying(_to) {
    require(cooldown[_from][_to] <= now);
    var _allowance = allowed[_from][_to];
    if (_from == selfAddress) {
        monthlyLimit[_to] = safeSub(monthlyLimit[_to], _value);
    }
    balances[_to] = balances[_to] + _value;
    balances[_from] = safeSub(balances[_from], _value);
    allowed[_from][_to] = safeSub(_allowance, _value);
    addUser(_to);
    Transfer(_from, _to, _value);
}
```

But this also cannot cause inconsistent state. Either `monthlyLimit[_to]` is already set (via a previous invocation of `addUser`) or it will be zero initialized and the `safeSub` call will revert the transaction.
In the first case a second call to `addUser` will not update the state.


**Conclusion:** Not vulnerable. No inconsistent state possible.


##### 0x1257F00e0333d7c9F9c87aBF1DCE6e373A6492F6

[etherscan.io](https://etherscan.io/address/0x1257F00e0333d7c9F9c87aBF1DCE6e373A6492F6#code)

```solidity
function record(address from, address to) {
  require(from != 0);
  require(returnAddress[from] == 0);
  require(Ownable(msg.sender).owner() == owner);

  returnAddress[from] = to;
}
```

Trivial contract that can be reentered, but seems useless? the attacker must just return a constant address (i.e., the `owner` of the target contract) to register an not-yet initialized `returnAddress`. Reentrancy does not really change anything here.

**Conclusion:** no ether gains possible. reentrancy seems unnecessary. (MR)


##### 0x2880f03f181ee0967a00bac5346574f58f91b615

`LinkFund` contract

The only potential for reentrancy I see is in the `perform_withdraw` function, where there are two calls to an attacker supplied address:

* `token.balanceOf(address(this))` at the beginning of the function
* `token.transfer(msg.sender, tokens_to_withdraw)` at the end of the function

~~However, the first one should compile down to a `staticcall`, where reentrancy isn't possible due to the gas limits.~~ No, apparently not.

If the `perform_withdraw` is called with an attacker-controlled `tokenAddress`, then I don't think it is exploitable with reentrancy. One can reenter either `refund_me`, which sets the balance to zero before it is read by `perform_withdraw`, so no issue.
Reentering `perform_withdraw` does not seem useful if the token is fully attacker controlled.

So `tokenAddress` must be a legitimate token to gain something. One needs to find a token contract that performs a callback on the `balanceOf` function. Furthermore, the call to `balanceOf(address(this))` would probably invoke a callback registed by the target contract, which is not attacker controlled.
Given that the contract at hand does not know about `ERC777` or similar contracts, it is extremely unlikely that the call to the `balanceOf` function will return control back to the attacker.

**Conclusion:** Very very unlikely to be exploitable (MR)


##### 0x2ad1ce69ea75a79f6070394a1b712db14965e3b4

`LINKFund` contract, [see previous analysis](#0x2880f03f181ee0967a00bac5346574f58f91b615)


##### 0x2d52d1517f47e1ab7be6377a1f11fbd2c49978db

`EnnjinBuyer` somewhat similar to the `LINKFund` and `BuyerFund` contracts; but a bit more complex
[etherscan](https://etherscan.io/address/0x2d52d1517f47e1ab7be6377a1f11fbd2c49978db#code)

To trigger a callback to the attacker with the `personal_withdraw` function, the `developer` of the contract, would have to set a token using `set_token` that is actually a `ERC777` token. Highly unlikely that a reentrancy is even possible here.

The `withdraw_token` function allows the attacker to pass their own token address, which would potentially allow for callbacks.

However, both functions carefully set the mappings storing balances to 0 before calling out of the contract. As such, there is no inconsistent state, since the relevant code paths cannot be reentered anymore or do not have any effect (i.e., attempting to transfer or subtract the balance with 0).


**Conclusion:** No inconsistent state. (MR)


##### 0x3aD4FAD3CE0509475E5B4f597C53cbA38873cC46

`CommonWallet` contract

[CommonWallet contract on etherscan](https://etherscan.io/address/0x3aD4FAD3CE0509475E5B4f597C53cbA38873cC46#code)

A variant of [another contract](0xef86db910c71ffa3c80233bc9108dc51ad1e008a), but contains several logic bugs.

There is a buggy check for token balances; one can do something without having a prior token balance:
```solidity
require(tokenBalance[tokenAddr][msg.sender] < amount);
```

There is also a wrong `!` negation operator that reverts whenever a token successfully transfers:
```solidity
require( ! ERC20Token(tokenAddr).transfer(to_, amount));
```

Seems generally broken / potentially exploitable without reentrancy.


##### 0x3b1c6004e43bf49c521eb382dec02e6c3ff5272a

`LINKFund` contract

**Conclusion:** [see](#0x2ad1ce69ea75a79f6070394a1b712db14965e3b4) above

##### 0x5ab2e3f693e6961beea08c1db8a3602fcea6b36f

`BuyerFund` contract

[etherscan](https://etherscan.io/address/0x5ab2e3f693e6961beea08c1db8a3602fcea6b36f#code)


**Conclusion:** [see the LinkFund Analysis](#0x2880f03f181ee0967a00bac5346574f58f91b615)



##### 0x6c1bcb34142bffd35f57db626e0ac427af616a4d

`EnnjinBuyer`, but slightly different from the [other version](#0x2d52d1517f47e1ab7be6377a1f11fbd2c49978db)

[etherscan](https://etherscan.io/address/0x6c1bcb34142bffd35f57db626e0ac427af616a4d#code)


##### 0xb29405833e303db3193CF7c058e2C81eF027C6C8

`BuyerFund` contract variant

[etherscan](https://etherscan.io/address/0xb29405833e303db3193CF7c058e2C81eF027C6C8#code)

**Conclusion**  [see](#0x5ab2e3f693e6961beea08c1db8a3602fcea6b36f)

##### 0x7b203459eb87fbf70ca42624b4304dc24ede9c50

`COE` contract

[etherscan](https://etherscan.io/address/0x7b203459eb87fbf70ca42624b4304dc24ede9c50#code)

**Conclusion:** ???

##### 0x8b168e46281e72d410717b27a6ca97bf9f301173

`LINKFund` contract

**Conclusion:** [see](#0x2ad1ce69ea75a79f6070394a1b712db14965e3b4) above

##### 0xa395480a4a90c7066c8ddb5db83e2718e750641c

`PreSaleFund` contract

[etherscan](https://etherscan.io/address/0xa395480a4a90c7066c8ddb5db83e2718e750641c#code)

Seems to be exploitable with reentrancy:

```
Invest with 2 Ether
Divest with 2 Ether
 -> loggedTransfer
   -> Callback
     -> Divest with 2 Ether
```

**Conclusion:** in a second run EF/CF identifies the bug. using live-state does not work here; since there is no ether in the contract. (MR)


##### 0xaa12936a79848938770bdbc5da0d49fe986678cc

`PreSaleFund` contract

**Conclusion:** slight variation but attack same as [before](#0xa395480a4a90c7066c8ddb5db83e2718e750641c)

##### 0xb29405833e303db3193cf7c058e2c81ef027c6c8

`BuyerFund` contract

**Conclusion:** [see](#0x5ab2e3f693e6961beea08c1db8a3602fcea6b36f) above

##### 0xbd10c70e94aca5c0b9eb434a62f2d8444ec0649d

`LinkFund` contract

**Conclusion:** [see](#0x2ad1ce69ea75a79f6070394a1b712db14965e3b4) above

##### 0xbd10c70e94aca5c0b9eb434a62f2d8444ec0649d

`LinkFund` contract

**Conclusion:** [see](#0x2ad1ce69ea75a79f6070394a1b712db14965e3b4) above

##### 0xc477042db387dd59c038ca4b829a07964b674347

`LoanDirectory` contract

[etherscan](https://etherscan.io/address/0xc477042db387dd59c038ca4b829a07964b674347#code)

This one is a bit odd. There are no access control measures at all, so basically one can freely write to the only state variable `loans`.
Reentrancy is seems to be possible everywhere when the `.status()` calls are used.

The idea behind `registerLoanReplaceDuplicated`, seems to be to replace a Loan only if there is a duplicate at a different index. So one can do
```
registerLoanReplaceDuplicated(X, A, B)
 |-> loan.status()
   |-> registerLoanReplaceDuplicated(X, B, A)
```
To remove both loans at `A` and `B` regardless of their status. From the `registerLoanReplace` function one can guess that a Loan is only supposed to be replaced if the `.status()` is not `"STATUS_INITIAL"`, so this seems to be an actual attack scenario.

The `registerLoanReplace` can also be reentered, but cannot cause actual inconsistent state, i.e., the same could be done with sequential calls.


**Conclusion:** True alarm for `registerLoanReplaceDuplicated`


##### 0xcc1a13b76270a20a78f3bef434bdeb4a5eec6a31

`ENJ` contract, seems to be a simpler version of the `EnjinBuyer` contract. Here only the `withdraw_token` functions seems tobe interesting. Similar to the same function in the [EnjinBuyer contract](#0x2d52d1517f47e1ab7be6377a1f11fbd2c49978db), the `withdraw_token` sets the `balances[msg.sender] = 0` and as such no inconsistent state is possible.


##### 0xd022969da8a1ace11e2974b3e7ee476c3f9f99c6

`PreSaleFund` contract

**Conclusion:** slight variation but attack same as [before](#0xa395480a4a90c7066c8ddb5db83e2718e750641c)

##### 0xd37e1d4509838d65873609158d1471627f697874

`BuyerFund` contract variant

**Conclusion:** [see](#0x5ab2e3f693e6961beea08c1db8a3602fcea6b36f) above


##### 0xdd1d5ce9f8e26a3f768b1c1e5c68db10a05d5fc0

`WeBetCrypto` variant [see also](#0x03c18d649e743ee0b09f28a81d33575f03af9826)
There are quite a few changes, but none relevant to the reentrancy issue.


##### 0xef86db910c71ffa3c80233bc9108dc51ad1e008a

`CommonWallet` contract, [etherscan code](https://etherscan.io/address/0xef86db910c71ffa3c80233bc9108dc51ad1e008a#code)

We also have another variant here but, it contains several other logic bugs [see](#0x3aD4FAD3CE0509475E5B4f597C53cbA38873cC46).

Reentrancy during token transfer:

```solidity
function sendTokenTo(address tokenAddr, address to_, uint256 amount) public {
    require(tokenBalance[tokenAddr][msg.sender] >= amount);
    if(ERC20Token(tokenAddr).transfer(to_, amount))
    {
        tokenBalance[tokenAddr][msg.sender] = safeSub(tokenBalance[tokenAddr][msg.sender], amount);
    }
}
```

**Conclusion:** Reentrancy possible, but only with Token with callback mechanism. Legitimate ERC20 Token likely not affected. Furthermore, the `safeSub` might revert any attack attempts (MR)


##### 0xfe2a80103c9037354a04094972fc7ecab747272b

`COE` clone

**Conclusion:** [see](#0x7b203459eb87fbf70ca42624b4304dc24ede9c50)

