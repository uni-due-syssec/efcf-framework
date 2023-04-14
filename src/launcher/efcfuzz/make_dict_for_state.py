#!/usr/bin/env python3
# Copyright 2022 Michael Rodler
# This file is part of efcfuzz launcher.
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as published
# by the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with this program. If not, see <https:#www.gnu.org/licenses/>.

import math
import os
import sys

from pathlib import Path

from .state import load_state_json, load_state_msgpack
from .utils import looks_like_address, normalize_ethereum_address, logw


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


def make_dict_for_state(state,
                        eevm_path,
                        interesting=[],
                        max_size=(2**16),
                        storage_key_threshold=64,
                        include_storage_interesting=True,
                        include_storage_all=False):
    fuzzdict = set()
    contract_dict_base = (Path(eevm_path) / "fuzz" / "dict/").expanduser().absolute()
    interesting_addrs = []
    for i in interesting:
        if isinstance(i, str):
            try:
                interesting_addrs.append(int(i, 0))
            except ValueError:
                pass

    # we add all interesting addresses to the state dictionary. The assumption
    # is that we need to tell the fuzzer about the various addresses, e.g., to
    # trigger interactions between the contracts
    for addr in interesting_addrs:
        fuzzdict.add(int2dictbytes(addr))

    if len(fuzzdict) > max_size:
        return fuzzdict

    # we attempt to locate the contract specific dictionaries, i.e., those that
    # were produced by evm2cpp. This should give use the 4byte identifiers and any
    # constants used in the code.

    def locate_and_add_dict(addr):
        addrs = normalize_ethereum_address(addr)

        fpath = None
        if contract_dict_base.exists():
            fpath = contract_dict_base / (f"{addrs}.dict")
            if not fpath.exists():
                for dictfile in os.listdir(contract_dict_base):
                    if addrs.lower() in dictfile.lower():
                        fpath = os.path.join(contract_dict_base, dictfile)
                        break
                else:
                    fpath = None

        if fpath is not None and fpath.exists():
            with open(fpath) as f:
                fuzzdict.update(map(str.strip, f.readlines()))
        else:
            logw(f"failed to locate evm2cpp-generated auto-dictionary for contract {addrs}")

    
    for addr in interesting:
        locate_and_add_dict(addr)
        if len(fuzzdict) > max_size:
            return fuzzdict

    # scan the storage contents for potentially interesting values.
    def handle_storage(addr):
        if state.exists(addr):
            account = state[addr]
            for k, v in account.storage.items():
                # mappings and dynamic arrays are usually located at higher
                # storage addresses. "global variable" aka. normal member
                # variables are located in the first couple of storage slots.
                # We assume that the interesting values (such as addresses of
                # other contracts or total balances) are in the lower
                # storage slots.
                if k < storage_key_threshold:
                    if interesting_val(v) or looks_like_address(v):
                        fuzzdict.add(int2dictbytes(v))
                if looks_like_address(v):
                    fuzzdict.add(int2dictbytes(v))

    # by default, we only scan the "interesting" addresses, i.e., those
    # addresses that the user explicitely specified to export.
    if include_storage_interesting:
        for addr in interesting_addrs:
            handle_storage(addr)

    if len(fuzzdict) > max_size:
        return fuzzdict

    for addr in state.accounts.keys():
        locate_and_add_dict(addr)
        if len(fuzzdict) > max_size:
            return fuzzdict

    # scanning all available accounts tends to blow up the dictionary, so it is
    # disabled by default.
    if include_storage_all:
        for addr in state.accounts.keys():
            if len(fuzzdict) > max_size:
                break
            handle_storage(addr)

    return fuzzdict


def main():
    EEVM_PATH = os.environ.get("EVM_PATH", "../src/eEVM/")

    if not os.path.exists(EEVM_PATH):
        raise ValueError("please set correct EVM_PATH env var")
    if len(sys.argv) != 2 or not os.path.exists(sys.argv[1]):
        raise ValueError("invalid CLI args")

    fname = sys.argv[1]
    if fname.endswith(".json"):
        state = load_state_json(fname)
    else:
        state = load_state_msgpack(fname)
    d = make_dict_for_state(state, EEVM_PATH)
    print("\n".join(sorted(d)))


if __name__ == "__main__":
    main()
