#!/usr/bin/env python3
import os
import sys
import json
import math

EEVM_PATH = os.environ.get("EVM_PATH", "../src/eEVM/")

if not os.path.exists(EEVM_PATH):
    raise ValueError("please set correct EVM_PATH env var")


def int2dictbytes(i):
    if not isinstance(i, int):
        i = int(i, 0)
    length = math.ceil(i.bit_length() / 8.0)
    ibytes = i.to_bytes(byteorder='big', length=length)
    bstr = "".join(f"\\x{v:02X}" for v in ibytes)

    return "\"" + bstr + "\""


def interesting_val(i):
    if i < 256:
        return False

    return any(b != 0 or b != 1 or b != 0xff
               for b in i.to_bytes(32, byteorder='big'))


def gather_values(state):
    fuzzdict = set()

    for account in state['accounts']:
        addr = account[0].strip()
        fuzzdict.add(int2dictbytes(int(addr, 16)))

        for k, v in account[1][1].items():
            k = int(k, 16)
            v = int(v, 16)

            if interesting_val(k):
                fuzzdict.add(int2dictbytes(k))

            if interesting_val(v):
                fuzzdict.add(int2dictbytes(v))

        fpath = None
        contract_dict_base = os.path.join(EEVM_PATH, "fuzz/dict/")
        if os.path.exists(contract_dict_base):
            fpath = os.path.join(contract_dict_base, f"{addr}.dict")
            if not os.path.exists(fpath):
                for dictfile in os.listdir(contract_dict_base):
                    if addr.lower() in dictfile.lower():
                        fpath = os.path.join(contract_dict_base, dictfile)
                        break
                else:
                    fpath = None

        if fpath:
            with open(fpath) as f:
                fuzzdict.update(map(str.strip, f.readlines()))

    return fuzzdict


if __name__ == "__main__":
    with open(sys.argv[1]) as f:
        state = json.load(f)
    d = gather_values(state)
    print("\n".join(sorted(d)))
