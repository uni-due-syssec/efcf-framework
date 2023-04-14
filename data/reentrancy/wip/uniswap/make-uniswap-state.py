import json
import os
import subprocess as sp
from pathlib import Path

base_state = {
    "accounts": [
        [
            "0xFFcf45b540e6C9F094Ae656D2e34aD11cdfdb187".lower(),
            [{
                "address":
                "0xFFcf45b540e6C9F094Ae656D2e34aD11cdfdb187".lower(),
                "balance": "0xb1a2bc2ec50000",
                "nonce": "0x0",
                "code": ""
            }, {
                "0x0":
                "0x556e697377617020563100000000000000000000000000000000000000000000",
                "0x1":
                "0x554e492d56310000000000000000000000000000000000000000000000000000",
                "0x2":
                "0x0000000000000000000000000000000000000000000000000000000000000012",
                "0x3":
                "0x00000000000000000000000000000000000000000000000000b1a2bc2ec50000",
                "0x4":
                "0x0000000000000000000000000000000000000000000000000000000000000000",
                "0x5":
                "0x0000000000000000000000000000000000000000000000000000000000000000",
                "0x6":
                "0x0000000000000000000000003212b29e33587a00fb1c83346f5dbfa69a458923",
                "0x7":
                "0x000000000000000000000000c0a47dfe034b400b47bdad5fecda2621de6c4d95",
                "0x568799952a42a6f4f8a949e55c4fc10c8db004372d2b3c7b408853757c5f63b5":
                "0x00000000000000000000000000000000000000000000000000b1a2bc2ec50000"
            }]
        ],
        [
            "0xc0a47dfe034b400b47bdad5fecda2621de6c4d95".lower(),
            [{
                "address":
                "0xc0a47dfe034b400b47bdad5fecda2621de6c4d95".lower(),
                "balance": "0x0",
                "nonce": "0x0",
                "code": ""
            }, {}]
        ],
        [
            "0x1820a4b7618bde71dce8cdc73aab6c95905fad24".lower(),
            [{
                "address":
                "0x1820a4b7618bde71dce8cdc73aab6c95905fad24".lower(),
                "balance": "0x1337",
                "code": "",
                "nonce": "0x0"
            }, {
                "0x194ac105769f523be18363ea37f40663f6a3a4ffb726b38b4bb459f7b0927383":
                "0x3212b29e33587a00fb1c83346f5dbfa69a458923",
                "0x5dcbcc2c4606d24cf552e27b1044e39123991fd7c437d41e3c120ce370d965b3":
                "0x3212b29e33587a00fb1c83346f5dbfa69a458923"
            }]
        ],
        [
            "0x3212b29e33587a00fb1c83346f5dbfa69a458923".lower(),
            [
                {
                    "address":
                    "0x3212b29e33587a00fb1c83346f5dbfa69a458923".lower(),
                    "balance": "0x0",
                    "code": "",
                    "nonce": "0x0"
                },
                {
                    "0x0":
                    "0x1820a4b7618bde71dce8cdc73aab6c95905fad24",
                    "0x1":
                    "0x0",
                    "0x2":
                    "0x449dfe26ff6fa7f0f5780000",
                    "0x3":
                    "0xdf4ae35230cb8f1",
                    "0x4":
                    "0x54686520546f6b656e697a656420426974636f696e000000000000000000002a",
                    "0x5":
                    "0x696d42544300000000000000000000000000000000000000000000000000000a",
                    "0x6":
                    "0x8",
                    "0xa":
                    "0xb9e29984fe50602e7a619662ebed4f90d93824c7",
                    "0xd":
                    "0x41f8d14c9475444f30a80431c68cf24dc9a8369a0100",
                    # storage mapping variables
                    "0x42e9ea57211f306ae021618a00eca8562600ae843c3a3b6086b698f29e5b59cd":
                    "0x1",
                    "0x821cab30c61e593c5157297eb9d9a1fef23ff55828c4d4796ba8c60d716fb4c7":
                    "0x000000000000000000000000000000000000000000001511e7e30a6807300000",
                    "0x821cab30c61e593c5157297eb9d9a1fef23ff55828c4d4796ba8c60d716fb4c8":
                    "0x0000000000000000000000000000000000000000000000000df487f24600c1bd",
                    "0x3707df012594d76a6000017e0ee0a6b1b4736ec3828ca78ed55b4d262dd246bd":
                    "0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff",
                    "0x4622ea35749170ccf63af914908eaf02cef2141b56217ba18a4fdffee583d662":
                    "0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff",
                    "0xae4baa6c8d668087e981382712c5296dc51c5b51dc9fc5f5a4e0445965e8f83e":
                    "0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff",
                    "0xbc65940b4e5c7671c5a92456fd59ec77acf6f41ff3dd54691b9da10e36856eec":
                    "0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff",
                    "0xe09b148861296d00aaeff640b56270bfffc0772f8f3a6988d67c7457985f6aef":
                    "0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff"
                }
            ]
        ]
    ],
    "block": {
        "currentCoinbase": "0xff42421337",
        "currentDifficulty": "0x9163c3ed1a37d",
        "currentGasLimit": "0xffffff",
        "currentNumber": "0x8a61c8",
        "currentTimestamp": "0x5dec42e6"
    }
}

# what?
"""
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
"""

addrlist = []
abilist = []

for (i, account) in enumerate(base_state['accounts']):
    addr = account[0]
    accst = account[1][0]

    if addr.lower() == "0xFFcf45b540e6C9F094Ae656D2e34aD11cdfdb187".lower():
        path = Path("./uniswap.bin-runtime")
        assert path.exists()
        with path.open() as f:
            accst['code'] = f.read().strip()
        addrlist.append(addr.lower())
        abilist.append(os.path.abspath("./uniswap.abi"))
    elif addr.lower() == "0xc0a47dfe034b400b47bdad5fecda2621de6c4d95".lower():
        path = Path("./ExchangeFactory.bin-runtime")
        sp.check_call(['make', 'exchange_factory.mock'])
        assert path.exists(), f"{path} does not exist"
        with path.open() as f:
            accst['code'] = f.read().strip()
        # addrlist.append(addr.lower())
        # abilist.append(os.path.abspath("./ExchangeFactory.abi"))
    elif addr.lower() == "0x3212b29E33587A00FB1C83346f5dBFA69A458923".lower():
        path = Path("./IMBTC.bin-runtime")
        sp.check_call(['make', 'IMBTC', "SOLC_VERSION=0.5.0"])
        assert path.exists(), f"{path}"
        with path.open() as f:
            accst['code'] = f.read().strip()
        addrlist.append(addr.lower())
        abilist.append(os.path.abspath("./IMBTC.abi"))
    elif addr.lower() == "0x1820a4B7618BdE71Dce8cdc73aAB6C95905faD24".lower():
        path = Path("./ERC1820Registry.bin-runtime")
        sp.check_call(['make', 'ERC1820Registry', "SOLC_VERSION=0.5.3"])
        assert path.exists()
        with path.open() as f:
            accst['code'] = f.read().strip()
        addrlist.append(addr.lower())
        abilist.append(os.path.abspath("./ERC1820Registry.abi"))

OUT_PATH = str(Path("/tmp/state.json").absolute())

with open(OUT_PATH, "w") as f:
    json.dump(base_state, f)

sp.check_call(['efcf-compile-state', OUT_PATH])

print("========================================================")
print("making multi-target-multi-abi output files in eevm dir")
p = os.environ.get("EEVM_DIR", '.')
with open(os.path.join(p, "full.state.load.json"), 'w') as f:
    json.dump(base_state, f)
with open(os.path.join(p, "addr_list.txt"), 'w') as f:
    f.write(",".join(addrlist))
# this is useful if on the branch of the ethmutator that supports multi-abi fuzzing
with open(os.path.join(p, "abi_list.txt"), 'w') as f:
    f.write(",".join(abilist))

print("========================================================")
print("now run:")
print("cd", p)
ta = '0xFFcf45b540e6C9F094Ae656D2e34aD11cdfdb187'.lower()
print('env AFL_BENCH_UNTIL_CRASH=1',
      'EVM_LOAD_STATE="$(pwd)/full.state.load.json"',
      f"EVM_TARGET_ADDRESS={ta}",
      'EVM_TARGET_MULTIPLE_ADDRESSES=`cat ./addr_list.txt`',
      'ABI_PATH=`cat ./abi_list.txt`', './fuzz/launch-aflfuzz.sh', ta)
print()
print()
print("optionally, add the fuzz seeds for the ERC1820Registry")
print()
print("FUZZ_SEEDS_DIR=" + os.path.realpath("./erc1820_seeds/"))
