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

import copy
import datetime
import json
import logging
import os
import random
import sys
import time
from collections import OrderedDict

import requests
from eth_utils import keccak
from requests import RequestException

from .state import AccountState, ChainState
from .utils import (log, loge, logw, looks_like_address,
                    normalize_ethereum_address)
"""
This constant is the upper bound to the number of contracts that will be added
to a state export.
"""
DEFAULT_MAX_STATE_SIZE = 250

"""
The state export searches for addresses in the storage space of the target and
includes those addresses in the state export. This allows to automatically
include dependecies into the state export, e.g., when dealing with
delegatecall-proxies or similar. However, by default the state export will not
recurse into any address that is found at a storage key higher than the
following constant. This ensures that no unrelated and unuseful accounts are
added to the state export, unnecessarily bloating the stat export (bad for
fuzzing perf!)
"""
DEFAULT_MAX_STORAGE_KEY = 512

DEFAULT_BLOCK_NUMBER = 0x8a61c8
DEFAULT_BLOCK_HASH = "0x072cf1df374159c5f23087750d8a2f3201542da196939ce446ff2c5c390fe5f6"
URL = 'http://localhost:8545'
DEFAULT_PARAMS_STORAGE_RANGE = [
    DEFAULT_BLOCK_HASH, 0, None, "0x00", 0x7FFFFFFF
]

CHAINSTATE = ChainState(number=DEFAULT_BLOCK_NUMBER,
                        difficulty=0x9163c3ed1a37d,
                        gas_limit=0xffffff,
                        coinbase=0xff42421337,
                        timestamp=0x5dec42e6)


def set_geth_url(newurl):
    global URL

    if not (newurl.startswith("http://") or newurl.startswith("https://")):
        logw(
            f"go-ethereum URL {newurl!r} without protocol -> guessing http://")
        newurl = "http://" + newurl

    if newurl != URL:
        URL = newurl

    res, err = exec_rpc_method("eth_blockNumber", [])

    if not res or err:
        loge(f"Failed to get blockNumber from go-ethereum url {URL}")

    return res and not err


def get_geth_blocknumber():
    global DEFAULT_BLOCK_NUMBER
    return DEFAULT_BLOCK_NUMBER


def update_config_to_blocknumber(blocknumber="latest"):
    global DEFAULT_BLOCK_HASH
    global DEFAULT_BLOCK_NUMBER
    global DEFAULT_PARAMS_STORAGE_RANGE
    global CHAINSTATE

    if isinstance(blocknumber, int):
        blocknumber = hex(blocknumber)
    res, err = exec_rpc_method("eth_getBlockByNumber", [blocknumber, False])

    if not res or err:
        loge(f"failed to get latest block from {URL} - {err!s}")

        return False
    blocknum = int(res['number'], 0)

    while len(res['transactions']) == 0:
        logw(
            f"latest block with number {blocknum} has no transactions - trying previous block"
        )
        blocknum -= 1
        if blocknum == 0:
            loge("reached block nr 0 - try a different start block number")
            return False
        res, err = exec_rpc_method("eth_getBlockByNumber",
                                   [hex(blocknum), False])

        if not res or err:
            loge(f"failed to get block {blocknum} from {URL} - {err!s}")

            return False
        blocknum = int(res['number'], 0)

    DEFAULT_BLOCK_NUMBER = blocknum
    DEFAULT_BLOCK_HASH = res['hash']

    CHAINSTATE.number = blocknum
    CHAINSTATE.difficulty = int(res['difficulty'], 0)
    CHAINSTATE.timestamp = int(res['timestamp'], 0)
    DEFAULT_PARAMS_STORAGE_RANGE[0] = DEFAULT_BLOCK_HASH

    dt = datetime.datetime.fromtimestamp(CHAINSTATE.timestamp)
    log(f"Using block {DEFAULT_BLOCK_NUMBER} from {dt!s} with block hash {DEFAULT_BLOCK_HASH}"
        )

    return True


def update_config_to_preset(presetname):
    global DEFAULT_BLOCK_HASH
    global DEFAULT_BLOCK_NUMBER
    global DEFAULT_BLOCK_DICT
    global DEFAULT_PARAMS_STORAGE_RANGE

    if presetname == "latest":
        return update_config_to_blocknumber("latest")
    elif presetname == "old":
        DEFAULT_BLOCK_NUMBER = 0x8a61c8
        # DEFAULT_BLOCK_HASH = "0x072cf1df374159c5f23087750d8a2f3201542da196939ce446ff2c5c390fe5f6"
        return update_config_to_blocknumber(DEFAULT_BLOCK_NUMBER)
    else:
        loge(f"invalid preset name {presetname}")

        return False

    return True


def exec_rpc_method(method, params, timeout=240):
    payload = {"jsonrpc": "2.0", "method": method, "params": params, "id": 1}
    headers = {'Content-Type': 'application/json'}
    try:
        r = requests.post(URL,
                          data=json.dumps(payload),
                          headers=headers,
                          timeout=timeout)

        if r.status_code != requests.codes.ok:
            return None, "RPC failed: status_code not ok. (method {})".format(
                method)
        data = r.json()

        if "result" in data:
            return data["result"], None
        elif "error" in data:
            return None, "RPC failed with Error {} - {}".format(
                data["error"], method)
    except RequestException as e:
        logw(
            f"encountered exception '{e}' while performing RPC call {method!r} with {params!r}"
        )
        return None, "RPC @ {} failed with Exception: {}".format(method, e)


def debug_traceTransaction(txHash):
    pl = {
        "disableStack": False,
        "disableMemory": False,
        "disableStorage": False
    }
    params = [txHash, pl]

    return exec_rpc_method("debug_traceTransaction", params)


def get_storage_range(contract_address):
    params = list(iter(DEFAULT_PARAMS_STORAGE_RANGE))
    params[2] = contract_address

    max_tries = 3
    for i in range(max_tries):
        try:
            res, err = exec_rpc_method("debug_storageRangeAt", params)
            break
        except ValueError as e:
            secs = 5
            logw("failed to fetch storage, trying again in", secs,
                 " seconds; reason: ", e)
            time.sleep(secs)
            if i == (max_tries - 1):
                raise

    if not res:
        raise ValueError(
            f"failed to get storage for {contract_address} due to {err!r}")

    if res["nextKey"] is not None:
        json.dump(res, sys.stderr)
        raise ValueError("expected 'nextKey' in result to be None/null!")

    storage = {}
    for i in res['storage'].values():
        try:
            if i["key"] is None:
                logw(
                    "encounterd storage entry without key ¯\\_(ツ)_/¯ ignoring")
                continue
            k = int(i["key"], 16)
            if i['value'] is None:
                v = 0
            else:
                v = int(i["value"], 16)
            storage[k] = v
        except (TypeError, ValueError):
            loge(
                "encountered invalid storage data retrieved data from geth -> "
                + str(i))
            raise
    return storage


def get_code(contract_address, number=None):
    if number is None:
        number = DEFAULT_BLOCK_NUMBER
    if isinstance(number, int):
        number = hex(number)
    if not isinstance(contract_address, str) or len(contract_address) != 42:
        contract_address = normalize_ethereum_address(contract_address)
    res, err = exec_rpc_method("eth_getCode", [contract_address, number])

    if not res:
        raise ValueError(
            f"failed to get code for {contract_address} due to '{err!r}'")

    return res


def get_code_and_hash(contract_address, number=None):
    code = get_code(contract_address, number)
    if code.startswith("0x"):
        code_bin = code[2:]
    else:
        code_bin = code
    code_bin = bytes.fromhex(code_bin)
    if code_bin:
        code_hash = keccak(code_bin)
        return code, code_hash
    else:
        return None, None


def get_balance(contract_address, number=None):
    if number is None:
        number = DEFAULT_BLOCK_NUMBER
    if isinstance(number, int):
        number = hex(number)
    if not isinstance(contract_address, str) or len(contract_address) != 42:
        contract_address = normalize_ethereum_address(contract_address)
    res, err = exec_rpc_method("eth_getBalance", [contract_address, number])

    if not res:
        raise ValueError(
            f"failed to get balance for {contract_address} due to {err!r}")

    return int(res, 0)


def create_eevm_account_state(contract):
    balance = get_balance(contract, DEFAULT_BLOCK_NUMBER)
    code = get_code(contract, DEFAULT_BLOCK_NUMBER)
    codebin = None
    if len(code) > 0 and code != "0x":
        if code.startswith("0x"):
            code = code[2:]
        codebin = bytes.fromhex(code)
    storage = get_storage_range(contract)
    state = AccountState(balance=balance,
                         nonce=0x42,
                         code=codebin,
                         storage=storage)
    return state


def search_evm_code_for_addresses(code):
    if isinstance(code, str):
        if code.startswith("0x"):
            code = bytes.fromhex(code[2:])
        else:
            try:
                code = bytes.fromhex(code)
            except ValueError:
                pass
    if not isinstance(code, bytes):
        raise ValueError(
            "need to provide bytes-like type or hex string, but got {type(code)}"
        )

    # ghetto evm disassembler
    addrs = set()
    for i, op in enumerate(code):
        j = i + 1
        # PUSH20
        if op == 115 and len(code) - j >= 20:
            address = int.from_bytes(code[j:j + 20], byteorder='big')
            if looks_like_address(address):
                addrs.add(address)

    log("found",
        len(addrs),
        "potential addresses in code",
        level=logging.DEBUG)
    return addrs


def create_eevm_state(contracts,
                      scan_address_deps=False,
                      max_state_size=DEFAULT_MAX_STATE_SIZE,
                      rate_limit=True,
                      consider_all_storage_keys=False,
                      storage_key_max=DEFAULT_MAX_STORAGE_KEY):
    state = copy.deepcopy(CHAINSTATE)

    done = set()
    worklist = list(contracts)

    def add_to_worklist(addr):
        if isinstance(addr, int):
            addr_int = addr
        else:
            addr_int = int(addr, 0)
        log(f"checking address {addr_int:#x}", level=logging.DEBUG)
        if addr_int in done:
            return
        # these are likely pre-compiles - do not add them.
        if addr_int <= 255:
            return
        normalized = normalize_ethereum_address(addr_int)
        balance = get_balance(normalized)
        if balance > 0 or get_code(normalized) not in ("0x", ""):
            if normalized not in worklist:
                worklist.append(normalized)
                log("adding found address",
                    normalized,
                    "to state",
                    level=logging.DEBUG)

    while worklist:
        if rate_limit and len(done) % 25 == 0 and len(done) != 0:
            t = random.randint(3, 7)
            logw("rate limiting fetching state from go-ethereum - sleep for",
                 t, 'secs')
            time.sleep(t)
        contract = worklist.pop()
        contract_i = int(contract, 0)
        accst = create_eevm_account_state(contract)
        state[contract_i] = accst
        done.add(contract_i)
        if scan_address_deps:
            for storage_key, storage_val in accst.storage.items():
                if consider_all_storage_keys or storage_key < storage_key_max:
                    if looks_like_address(storage_val):
                        add_to_worklist(storage_val)

            code = accst.code
            if code:
                log("searching for addresses in code of",
                    contract,
                    level=logging.DEBUG)
                for a in search_evm_code_for_addresses(code):
                    add_to_worklist(a)

        if len(state.accounts) == max_state_size:
            logw("added", max_state_size, "contracts to state - stopping now!",
                 "you might want to use an artifically ",
                 "constructed state instead...")
            break

    log("added",
        len(contracts),
        "and identified",
        len(state.accounts) - len(contracts),
        "additional contracts",
        level=logging.DEBUG)

    return state


def main():
    if len(sys.argv) == 1 or "--help" in sys.argv or "-h" in sys.argv:
        print("usage:\n", "\t", sys.argv[0], "<path_to_list_of_addresses>\n",
              "\t", sys.argv[0], "<address> <address...>\n")
        sys.exit(1)

    def sanit(c):
        c = c.strip()

        if not c.startswith("0x"):
            raise ValueError(f"invalid contract address {c!r}")

        return c

    if os.path.exists(sys.argv[1]) or sys.argv[1] == "-":
        if sys.argv[1] == "-":
            f = sys.stdin
        else:
            f = open(sys.argv[1])

        contracts = map(sanit, f.readlines())
    else:
        contracts = map(sanit, sys.argv[1:])

    j = create_eevm_state(contracts)
    # json.dump(j, sys.stdout)
    from .state import dump_state_json
    dump_state_json(j, "/tmp/wut.json")
    print(open("/tmp/wut.json").read())

    sys.exit(0)


if __name__ == "__main__":
    main()
