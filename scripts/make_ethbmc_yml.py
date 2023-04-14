#!/usr/bin/env python3

import sys
import json

with open(sys.argv[1]) as f:
    contract = json.load(f)

code = next(iter(contract["contracts"].values()))["bin-runtime"]

print("""
victim: 0xaad62f08b3b9f0ecc7251befbeff80c9bb488fe9

state:
    0xaad62f08b3b9f0ecc7251befbeff80c9bb488fe9:
        balance: 0xde0b6b3a7640000
        nonce: 0x1000000
        code:""", code)
