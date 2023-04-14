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

import logging
import os
import subprocess as sp
import sys
import tempfile
import pathlib

from .meta import get_abi
from .state import ChainState, load_state_json, load_state_msgpack
from .utils import log, normalize_ethereum_address

EEVM_PATH = os.environ.get("EVM_PATH", "../src/eEVM/")


def translate_whole_state(state: ChainState, eevm_path=None):
    if eevm_path is None:
        eevm_path = EEVM_PATH

    for addr, account in state.accounts.items():
        addr = normalize_ethereum_address(addr)
        code = account.code
        if not code:
            continue
        log("translating", addr, "with code len", len(code))
        abi = get_abi(addr)
        if not abi:
            log("failed to get ABI for", addr, level=logging.WARNING)

        with tempfile.TemporaryDirectory() as td_name:
            cmd = ['evm2cpp', '-e', eevm_path]

            if abi:
                abi_path = os.path.join(td_name, "abi.json")
                with open(abi_path, "w") as f:
                    f.write(abi)
                cmd.extend(["--abi", abi_path])
            code_path = os.path.join(td_name, "code.bin-runtime")
            with open(code_path, "w") as f:
                if isinstance(code, bytes):
                    f.write("0x")
                    f.write(code.hex())
                elif isinstance(code, str):
                    if code.startswith("0x"):
                        f.write(code)
                    else:
                        f.write("0x")
                        f.write(code)

            cmd.extend([addr, code_path])

            log("running evm2cpp: ", *cmd)
            sp.check_call(cmd)


def print_usage(exitcode=1):
    log("usage", sys.argv[0], "<path_to_state.(json|msgpack)>", level=logging.ERROR)

    if exitcode is not None:
        sys.exit(exitcode)


def main():
    if not os.path.exists(EEVM_PATH):
        raise ValueError("please set correct EVM_PATH env var")

    if not len(sys.argv) == 2:
        print_usage()

    if not os.path.exists(sys.argv[1]):
        print_usage()

    fname = sys.argv[1]
    if fname.endswith(".json"):
        state = load_state_json(pathlib.Path(fname))
    else:
        state = load_state_msgpack(pathlib.Path(fname))
    translate_whole_state(state)


if __name__ == "__main__":
    main()
