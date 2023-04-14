#!/usr/bin/env python

import json
import os
import sys

addr_list = [
    '0xdeadbeefc5d48cec7275152b3026b53f6f78d03d',
    '0x1beefbeec5d48cec7275152b3026b53f6f78d03d'
]
state_tmpl = {
    "accounts": [
        [
            addr_list[0],
            [{
                "address": addr_list[0],
                "balance": "0x0",
                "code": "",
                "nonce": "0x0"
            }, {
                "0x00": addr_list[1],
            }]
        ],
        [
            addr_list[1],
            [{
                "address": addr_list[1],
                "balance": "0x0",
                "code": "",
                "nonce": "0x0"
            }, {
                "0x00": addr_list[0],
            }]
        ],
    ],
    "block": {
        "currentCoinbase": "0x0",
        "currentDifficulty": "0x0",
        "currentGasLimit": "0x0",
        "currentNumber": "0x1337",
        "currentTimestamp": "0x101010"
    }
}

with open(sys.argv[1]) as f:
    combinedjson = json.load(f)

if "DoubleFetch" in sys.argv[1]:
    # dirty constructor workaround
    state_tmpl['accounts'][0][1][1]["0x01"] = "0x02"
    state_tmpl['accounts'][0][1][0]['balance'] = "0x1000000000"

keys = [
    k for k in combinedjson['contracts'].keys()
    if "SafeMath" not in k and "MappingFunction" not in k
]
if "DoubleFetch" not in sys.argv[1]:
    keys = keys[::-1]

if "DistributedBank" in sys.argv[1]:
    keys.append(keys[0])
    state_tmpl['accounts'][0][1][0]['balance'] = "0x1000000000"
    state_tmpl['accounts'][1][1][0]['balance'] = "0x1000000000"

print("State Setup")
for k, a in zip(keys, addr_list):
    print(a, "=>", k)

codes = [combinedjson['contracts'][k]['bin-runtime'] for k in keys]

state_tmpl['accounts'][0][1][0]['code'] = codes[0]
state_tmpl['accounts'][1][1][0]['code'] = codes[1]

p = os.environ.get("EEVM_DIR", '.')
with open(os.path.join(p, "full.state.load.json"), 'w') as f:
    json.dump(state_tmpl, f)
with open(os.path.join(p, "addr_list.txt"), 'w') as f:
    f.write(",".join(addr_list))
# this is useful if on the branch of the ethmutator that supports multi-abi fuzzing
with open(os.path.join(p, "abi_list.txt"), 'w') as f:
    f.write(",".join(
        map(
            lambda x: os.path.abspath(
                os.path.join(p, "fuzz", "abi", f"{x}.abi")),
            map(lambda x: x.split(":")[-1], keys))))
