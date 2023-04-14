```sh
    npm install
    // if target contract exists in blockchain
    node launch-attack.js <attack_contract.sol> <target_address>

    // if target contract is crafted, then deploy bytecode (starts without 0x) and abi file is
    needed
    node launch-attack.js <attack_contract.sol> <bytecode_file> <abi_file>
```
