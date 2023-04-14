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
import os
import zipfile
from copy import copy
from pathlib import Path

from .utils import normalize_ethereum_address, run

ETHBMC_SPECIAL_ADDRESS = "0dfa72de72f96cf5b127b070e90d68ec9710797c".lower()
EFCF_SPECIAL_ADDRESS = "c04689c0c5d48cec7275152b3026b53f6f78d03d".lower()


def make_seeds_from_ethbmc_zip(seeds_dir: Path, address, zippath: Path):
    assert seeds_dir.exists()
    address = normalize_ethereum_address(address)
    with zipfile.ZipFile(zippath) as zipped:
        with zipped.open(f"final_result/{address}.json") as f:
            ethbmc_results = json.load(f)
    return make_seeds_from_ethbmc(seeds_dir, ethbmc_results)


def make_seeds_from_ethbmc(seeds_dir: Path, ethbmc_results: dict):
    template = {
        "number": 0,
        "difficulty": 0,
        "gas_limit": 0,
        "timestamp": 0,
        "initial_ether": 1000000000,
        "txs": []
    }
    tx_template = {
        "sender_select":
        0,
        "call_value":
        0,
        "length":
        0,
        "block_advance":
        1,
        "return_count":
        2,
        "input":
        "",
        "returns": [{
            "value": 1,
            'data': '',
            'length': 0,
            'reenter': 0
        }, {
            "value": 1,
            'data': '',
            'length': 0,
            'reenter': 0
        }]
    }

    os.makedirs(seeds_dir, exist_ok=True)

    for i, attack in enumerate(ethbmc_results['Success']['attacks']):
        attack_type = attack['attack_type']
        contents = copy(template)
        for etx in attack['txs']:
            tx = copy(tx_template)
            tx['call_value'] = int(etx.get('balance', "0x00"), 16)
            tx['input'] = "0x" + "".join(
                map(lambda x: x[2:], etx.get('input_data', ["0x"])))
            if ETHBMC_SPECIAL_ADDRESS in tx['input']:
                tx['input'] = tx['input'].replace(ETHBMC_SPECIAL_ADDRESS,
                                                  EFCF_SPECIAL_ADDRESS)
            contents['txs'].append(tx)

        p = seeds_dir / f"{i}_{attack_type}.yaml"
        with p.open("w") as f:
            json.dump(contents, f)

        as_bin_path = p.parent / (p.stem + ".bin")

        if run("efuzzcasetranscoder", p, as_bin_path) is None:
            return False

    return True


if __name__ == "__main__":
    # main()
    pass
