#!/usr/bin/env python

import os
import shutil
import subprocess as sp
from pathlib import Path

sender_addrs = [
    s.rjust(64, "0") for s in [
        "c04689c0c5d48cec7275152b3026b53f6f78d03d",
        "c1af1d7e20374a20d4d3914c1a1b0ddfef99cc61",
        "c2018c3f08417e77b94fb541fed2bf1e09093edd",
        "c3cf2af7ea37d6d9d0a23bdf84c71e8c099d03c2",
        "c4b803ea8bc30894cc4672a9159ca000d377d9a3",
        "c5442b23ea5ca66c3441e62bf6456f010646ae94",
    ]
]

header = """
---
number: 0
difficulty: 0
gas_limit: 0
timestamp: 0
initial_ether: 0
txs:"""
tmpl = """
  - length: 100
    return_count: 1
    receiver_select: 2
    sender_select: {sender}
    block_advance: 0
    call_value: 0
    # setInterfaceImplementer(address,bytes32 {hash_name},address)
    input: "0x{input_bytes}"
    returns:
      - value: 1
        reenter: 0
        data_length: 32
        # keccak(b"ERC1820_ACCEPT_MAGIC")
        data: "0xa2ef4600d742022d532d4747cb3547474667d6f13804902513b2ec01c848f4b4"
  - length: 68
    return_count: 1
    receiver_select: 2
    sender_select: {sender}
    block_advance: 0
    call_value: 0
    # getInterfaceImplementer(address,bytes32 {hash_name})
    input: "0xaabbb8ca0000000000000000000000000000000000000000000000000000000000000000{iface_hash}"
    returns:
      - value: 1
        reenter: 0
        data_length: 0
        data: "0x"
"""
# 0xaabbb8ca

ifaces_hashes = [
    ("aea199e31a596269b42cdafd93407f14436db6e4cad65417994c2eb37381e05a",
     'keccak("ERC20Token")'),
    ("ac7fbab5f54a3ca8194167523c6753bfeb96a445279294b6125b68cce2177054",
     'keccak("ERC777Token")'),
    ("29ddb589b1fb5fc7cf394961c1adf5f8c6454761adf795e67fe149f658abe895",
     'keccak("ERC777TokensSender")'),
    ("b281fc8c12954d22544db45de3159a39272895b169a852b314f9cc762e44c53b",
     'keccak("ERC777TokensRecipient")'),
]

tc = "efuzzcasetranscoder"
binseeds = Path("erc1820_seeds")
binseeds.mkdir(exist_ok=True)
ymlseeds = Path("erc1820_seeds_yml")
ymlseeds.mkdir(exist_ok=True)
for sender in range(0, 4):
    all_ifaces = header
    for iface_hash, hash_name in ifaces_hashes:
        input_bytes = ''.join(
            ["29965a1d", "00" * 32, iface_hash, sender_addrs[sender]])
        testcase = tmpl.format(sender=sender,
                               input_bytes=input_bytes,
                               iface_hash=iface_hash,
                               hash_name=hash_name,
                               sender_addr=sender_addrs[sender])
        all_ifaces += testcase
        testcase = header + testcase
        basename = f"{sender}_{hash_name[8:-2]}"
        ymlpath = (ymlseeds / (basename + ".yml"))
        with ymlpath.open("w") as f:
            f.write(testcase)

        if shutil.which(tc):
            outpath = (binseeds / (basename + ".bin"))
            sp.check_call([tc, str(ymlpath), str(outpath)])

    # a single testcase with calls to implement all the interface hashes we
    # know about
    basename = f"{sender}_allifaces"
    ymlpath = (ymlseeds / (basename + ".yml"))
    with ymlpath.open("w") as f:
        f.write(all_ifaces)

    if shutil.which(tc):
        outpath = (binseeds / (basename + ".bin"))
        sp.check_call([tc, str(ymlpath), str(outpath)])
