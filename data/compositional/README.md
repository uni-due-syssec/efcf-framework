# Uniswap/IMBTC

> On April 18, 2020, attackers were able to drain a large amount of  ether from  Uniswap’s  liquidity  pool  of  ETH-imBTC.

* (Target) `0xFFcf45b540e6C9F094Ae656D2e34aD11cdfdb187` => uniswap.vy
* `0xc0a47dfe034b400b47bdad5fecda2621de6c4d95` => exchange factory
* `0x3212b29E33587A00FB1C83346f5dBFA69A458923` => IMBTC token
* `0x1820a4B7618BdE71Dce8cdc73aAB6C95905faD24` => IERC1820Registry

Blocknumber: 9600000 (Mar-03-2020)

```
efcfuzz --verbose --until-crash --out ./out/live_state/uniswap_b9600000 \
    --live-state 0xFFcf45b540e6C9F094Ae656D2e34aD11cdfdb187,0x3212b29E33587A00FB1C83346f5dBFA69A458923,0x1820a4B7618BdE71Dce8cdc73aAB6C95905faD24 \
    --live-state-blocknumber 9600000 \
    --multi-target=y --include-address-deps=y \
    --compute-evm-cov=n --generate-cov-plots=n \
    --timeout 48h --cores 32
```


Detectable by EF/CF: yes


# Lendf.me/IMBTC

> On April 19, 2020, attackers were able to drain all of Lendf.me’s liquidity  pools

Blocknumber: 9890000 (April 17, 2020)

* `0x0eEe3E3828A45f7601D5F54bF49bB01d1A9dF5ea` => lendf.me MoneyMarket
* `0x3212b29E33587A00FB1C83346f5dBFA69A458923` => IMBTC token
* `0x1820a4B7618BdE71Dce8cdc73aAB6C95905faD24` => IERC1820Registry


```
efcfuzz --verbose --until-crash --out ./out/live_state/lendfme_b9890000 \
    --live-state 0x0eEe3E3828A45f7601D5F54bF49bB01d1A9dF5ea,0x3212b29E33587A00FB1C83346f5dBFA69A458923,0x1820a4B7618BdE71Dce8cdc73aAB6C95905faD24 \
    --live-state-blocknumber 9890000 \
    --multi-target=y --include-address-deps=y \
    --compute-evm-cov=n --generate-cov-plots=n \
    --timeout 48h --cores 32
```


# Cream Finance

TODO


# Revest Finance

Info:
* https://blocksecteam.medium.com/revest-finance-vulnerabilities-more-than-re-entrancy-1609957b742f
* https://twitter.com/BlockSecTeam/status/1508065573250678793

> A staking DeFi project on Ethereum has been exploited on March 27th 2022

Try Blocknumber: 14460000 Mar-26-2022


Attack TX:
* https://etherscan.io/tx/0xe0b0c2672b760bef4e2851e91c69c8c0ad135c6987bbf1f43f5846d89e691428/advanced#internal

Attacker calls:
* `0x2320A28f52334d62622cc2EaFa15DE55F9987eD9` Revest
* `0xe952bda8c06481506e4731C4f54CeD2d4ab81659` Revest FNFT Handler
* `0x56de8BC61346321D4F2211e3aC3c0A7F00dB9b76` RENA Token
* `0xbC2C5392b0B841832bEC8b9C30747BADdA7b70ca` Uniswap V2: RENA 3
* `0x1820a4B7618BdE71Dce8cdc73aAB6C95905faD24` ERC1820Registry


```
efcfuzz --verbose --until-crash --out ./out/live_state/revest_b14460000 \
    --live-state 0x2320A28f52334d62622cc2EaFa15DE55F9987eD9,0xe952bda8c06481506e4731C4f54CeD2d4ab81659,0x56de8BC61346321D4F2211e3aC3c0A7F00dB9b76,0xbC2C5392b0B841832bEC8b9C30747BADdA7b70ca,0x1820a4B7618BdE71Dce8cdc73aAB6C95905faD24 \
    --live-state-blocknumber 14460000 \
    --multi-target=y --include-address-deps=y \
    --compute-evm-cov=n --generate-cov-plots=n \
    --timeout 48h --cores 32
```
