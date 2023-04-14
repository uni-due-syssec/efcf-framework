# uniswap: imBTC state setup for fuzzing

* (Target) `0xFFcf45b540e6C9F094Ae656D2e34aD11cdfdb187` => uniswap.vy with
    * `self.factory = 0xc0a47dfe034b400b47bdad5fecda2621de6c4d95`
    * `self.token = 0x3212b29E33587A00FB1C83346f5dBFA69A458923`
    * `self.name = 0x556e697377617020563100000000000000000000000000000000000000000000`
      (*'Uniswap V1'*) 
    * `self.symbol = 0x554e492d56310000000000000000000000000000000000000000000000000000`
      (*'UNI-V1'*)
    * `self.decimals = 18`
* `0xc0a47dfe034b400b47bdad5fecda2621de6c4d95` => exchange_factory.mock.sol
* `0x3212b29E33587A00FB1C83346f5dBFA69A458923` => IMBTC
* `0x1820a4B7618BdE71Dce8cdc73aAB6C95905faD24` => IERC1820Registry

run the fuzzer with:

```
env EVM_TARGET_ADDRESS='0xFFcf45b540e6C9F094Ae656D2e34aD11cdfdb187' \
    EVM_LOAD_STATE=/path/to/uniswap.eevm.state.json \
        ./fuzz/launch-aflfuzz.sh uniswap
```


## More Information

* [Audit report](https://github.com/ConsenSys/Uniswap-audit-report-2018-12#31-liquidity-pool-can-be-stolen-in-some-tokens-eg-erc-777-29)
* [Attack transactions identified by Horus](https://github.com/christoftorres/Horus/blob/master/experiments/uniswap/results/UniswapHack.csv)
