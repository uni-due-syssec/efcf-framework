#!/usr/bin/env python

import os
import json
import sys

assert len(sys.argv) == 2, "requires path to abi file as command line argument"

combined = {}
with open(sys.argv[1]) as f:
    combined = json.load(f)

assert combined, "empty combined.json"


contract_deny = {"SafeMath"}
type_deny = {"constructor"}
abi_concat = []
for name, cdata in combined['contracts'].items():
    if any(n in name for n in contract_deny):
        continue
    print("[+] processing contract", name)
    abi = cdata['abi']
    if isinstance(abi, str):
        abi = json.loads(abi)
        abi_concat.extend(a for a in abi if a.get('type', None) not in type_deny)

p = os.environ.get("EEVM_DIR", '.')
with open(os.path.join(p, "concat.abi"), 'w') as f:
    json.dump(abi_concat, f, indent=2)
