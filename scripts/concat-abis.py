#!/usr/bin/env python

import os
import json
import sys

assert len(sys.argv) >= 2, "requires path to abi files as command line argument"

abi_concat = [] 
for path in sys.argv[1:]:
    assert os.path.exists(path), f"{path!r} doesn't exist"

    contract_deny = {"SafeMath"}
    for n in contract_deny:
        if n in path:
            continue

    abi = {}
    with open(path) as f:
        abi = json.load(f)
    if not abi:
        continue

    type_deny = {"constructor"}
    for a in abi:
        if a.get('type', None) not in type_deny and a not in abi_concat:
            abi_concat.append(a)

p = os.environ.get("EEVM_DIR", '.')
with open(os.path.join(p, "concat.abi"), 'w') as f:
    json.dump(abi_concat, f, indent=2)
