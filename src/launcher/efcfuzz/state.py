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

import json
import pathlib
from typing import Dict, Optional

import msgpack


def b2i(b: bytes) -> int:
    return int.from_bytes(b, "big")


def i2b(i: int) -> bytes:
    return i.to_bytes(32, "big")


class AccountState:
    balance: int
    nonce: int
    code: Optional[bytes]
    storage: Dict[int, int]

    def __init__(self, balance=0, nonce=0, code=None, storage=None):
        self.balance = balance
        self.nonce = nonce
        self.code = code
        if storage:
            if not isinstance(storage, dict):
                raise TypeError("invalid storage type " + str(type(storage)))
            self.storage = storage
        else:
            self.storage = {}


class ChainState:
    number: int
    difficulty: int
    gas_limit: int
    coinbase: int
    timestamp: int
    accounts: Dict[int, AccountState]

    def __init__(self,
                 number=0,
                 difficulty=0,
                 gas_limit=0,
                 timestamp=0,
                 coinbase=0):
        self.number = number
        self.difficulty = difficulty
        self.gas_limit = gas_limit
        self.timestamp = timestamp
        if isinstance(coinbase, bytes):
            coinbase = b2i(coinbase)
        self.coinbase = coinbase
        self.accounts = {}

    def __getitem__(self, address):
        # if address not in self.accounts:
        #     self.accounts[address] = AccountState()
        return self.accounts[address]

    def __setitem__(self, address, state):
        if not isinstance(address, int):
            raise TypeError("invalid type for address got " +
                            str(type(address)))
        if not isinstance(state, AccountState):
            raise TypeError("invalid type for state got " + str(type(state)))
        self.accounts[address] = state

    def create(self, address) -> AccountState:
        if address not in self.accounts:
            self.accounts[address] = AccountState()
        return self[address]

    def exists(self, address) -> bool:
        return address in self.accounts

    def size(self) -> int:
        return len(self.accounts)


"""
=== msgpack format ===
```
[
 number u64,
 difficulty u64,
 gas_limit u64,
 timestamp u64,
 coinbase u256,
 # accounts
 {
   address u256 : [
     balance u256,
     nonce u64,
     code bytes,
     # storage
     {
       key u256 : value u256,
       ...
     }
   ]
   ...
 }
]
```
"""


def load_state_msgpack(path: pathlib.Path) -> Optional[ChainState]:
    state = None
    with path.open("rb") as fb:
        obj = msgpack.unpack(fb)
        state = ChainState(*obj[:-1])
        accounts = obj[-1]
        for addr, acc_state in accounts.items():
            addr = b2i(addr)
            balance = b2i(acc_state[0])
            nonce = acc_state[1]
            code = acc_state[2]
            astate = AccountState(balance, nonce, code)
            for k, v in acc_state[3].items():
                astate.storage[b2i(k)] = b2i(v)
            state[addr] = astate
    return state


def dump_state_msgpack(state: ChainState, path: pathlib.Path):
    accounts: Dict[bytes, list] = {}
    for addr, acc in state.accounts.items():
        code = bytes(acc.code) if acc.code else bytes()
        accounts[i2b(addr)] = [
            i2b(acc.balance), acc.nonce,
            code,
            {i2b(k): i2b(v)
             for k, v in acc.storage.items()}
        ]
    data = [
        state.number, state.difficulty, state.gas_limit, state.timestamp,
        i2b(state.coinbase), accounts
    ]
    with path.open("wb") as fb:
        msgpack.pack(data, fb)


"""
===  json format ===
```
{
  "accounts" : [
      [
        "0x...",
        [
            {
                "address": "0x...",
                "balance": "0x...",
                "code": "0x...",
                "nonce": "0x..."
            },
            {
                "0x...": "0x...",
                ...
            }
        ]
      ],
      ...
  ],
  "block" : {
    "currentCoinbase": "0x...",
    "currentDifficulty": "0x...",
    "currentGasLimit": "0x...",
    "currentNumber": "0x...",
    "currentTimestamp": "0x..."
  }
}
```

"""


def load_state_json(path: pathlib.Path) -> ChainState:
    data = None
    with path.open() as f:
        data = json.load(f)
    block = data['block']
    state = ChainState(number=int(block.get('currentNumber', "0x0"), 0),
                       difficulty=int(block.get('currentDifficulty', "0x0"),
                                      0),
                       gas_limit=int(block.get('currentGasLimit', "0x0"), 0),
                       timestamp=int(block.get('currentTimestamp', "0x0"), 0),
                       coinbase=int(block.get('currentCoinbase', "0x0"), 0))
    for account in data['accounts']:
        addr = int(account[0], 0)
        balance = int(account[1][0]["balance"], 0)
        nonce = int(account[1][0]["nonce"], 0)
        _addr = int(account[1][0]["address"], 0)
        assert addr == _addr
        _code = account[1][0]["code"]
        if _code.startswith("0x"):
            _code = _code[2:]
        if _code:
            code = bytes.fromhex(_code)
        else:
            code = None
        storage = {int(k, 0): int(v, 0) for k, v in account[1][1].items()}
        s = AccountState(balance=balance, nonce=nonce, code=code)
        s.storage = storage
        state[addr] = s
    return state


def dump_state_json(state: ChainState, path: pathlib.Path):
    data = {
        "accounts": [[
            hex(addr),
            [{
                "address": hex(addr),
                "balance": hex(acc.balance),
                "nonce": hex(acc.nonce),
                "code": ("0x" + (acc.code.hex() if acc.code else ""))
            }, {hex(k): hex(v)
                for k, v in acc.storage.items()}]
        ] for addr, acc in state.accounts.items()],
        "block": {
            "currentCoinbase": hex(state.coinbase),
            "currentDifficulty": hex(state.difficulty),
            "currentGasLimit": hex(state.gas_limit),
            "currentNumber": hex(state.number),
            "currentTimestamp": hex(state.timestamp)
        }
    }
    with path.open("w") as f:
        json.dump(data, f)
