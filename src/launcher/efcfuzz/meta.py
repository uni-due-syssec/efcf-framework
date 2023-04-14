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

import os
from typing import Optional

import requests

ETHERSCAN_URL = "https://api.etherscan.io/api?apikey={apikey}"
ETHERSCAN_GET_ABI = "&module=contract&action=getabi&address={address}"
ETHERSCAN_GET_CODE = "&module=proxy&action=eth_getCode&address={address}"
ETHERSCAN_API_KEY = os.environ.get("ETHERSCAN_API_KEY", "")


def get_abi(contract_address: str) -> Optional[str]:
    url = (ETHERSCAN_URL + ETHERSCAN_GET_ABI).format(address=contract_address,
                                                     apikey=ETHERSCAN_API_KEY)
    resp = requests.get(url)

    if resp.status_code != 200:
        raise Exception("HTTP ERROR, CODE: {}".format(resp.status_code))

    res = resp.json()

    if (res["status"] == "0" or not res["result"]):
        return None

    return res['result']


def get_code(contract_address: str) -> Optional[str]:
    url = (ETHERSCAN_URL + ETHERSCAN_GET_CODE).format(address=contract_address,
                                                      apikey=ETHERSCAN_API_KEY)
    resp = requests.get(url)

    if resp.status_code != 200:
        raise Exception("HTTP ERROR, CODE: {}".format(resp.status_code))

    res = resp.json()

    if (res["status"] == "0" or not res["result"]):
        return None

    return res['result']
