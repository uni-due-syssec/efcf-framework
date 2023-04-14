# Serif Dataset

The following contracts were used in the evaluation in the paper:

> Cecchetti, E., Yao, S., Ni, H., & Myers, A. C. (2021). Compositional Security for Reentrant Applications. 2021 IEEE Symposium on Security and Privacy (SP)

The contracts are written in a custom language that supports information flow
control as part of the type system. We back-translate those contracts into
regular Solidity code. Additionally, we perform several changes and bug fixes.

The updated contracts are located in other directories as part of other
datasets where they fit better.

* **Multi-Dao** (`../tests-multi-abi/DistributedBankExW0.sol`) We remove some
  code from the `deposit()` function that made it impossible to deposit Ether.
* **KV Store** (`../tests-multi-abi/MapW0.sol`)
    * We introduce a `selfdestruct`-based bug oracle, s.t. an invariant
      violation can be more easily detected by a standard fuzzer.
    * The contract used by Serif is not actually vulnerable to an reentrancy attack.
      We change the `isMapped` function s.t., a reentrant access to the second
      contract actually makes a difference and violates a property of the
      contract.
* **Uniswap** (`../reentrancy/UniswapEx.sol`)
    * We adapt the code to trade Tokens for Ether, s.t., the Uniswap contract
      can be exploited to gain Ether.
    * We implement missing functions that are necessary to perform exploitation,
      such as the function to trade Ether and Tokens in both directions and a
      function to airdrop an initial amount of tokens to the Uniswap contract.
      With this functions the Uniswap contract becomes exploitable.
* **Town Crier** (`../assertions-tests/TownCrierSimple.sol`)
    * We modified the contract s.t., a reentrancy attack allows the attacker to
      use the Town Crier services for free without paying the otherwise
      required fee in Ether.
    * The Town Crier contract requires a blockchain-external component to
      deliver data into the blockchain by monitoring the contract and
      responding to requests. We simulate this external component with the
      fuzzer, but need to make sure that the fuzzer cannot abuse this to gain
      Ether. Therefore, we send the fees to another non-fuzzer controlled
      address and disable returning fees to the sender on errors.
    * We add an assertion-like check to identify the bug, because the attack
      does not allow the attacker to gain Ether, but just to bypass the
      required fee payment (i.e., attacker has no loss, but also no gain).
