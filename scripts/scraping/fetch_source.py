#!/usr/bin/env python3

import json
import logging
import os
import sys
from pathlib import Path

import coloredlogs
import requests

log = logging.getLogger()

ETHERSCAN_API_TEMPLATE = "https://api.etherscan.io/api?module=contract&action=getsourcecode&address={address}&apikey={key}"

CONTRACTS_DIR = Path(".")
EXTENSION = ".meta.json"
FAILED_LIST = "failed_contract_list.csv"

OVERWRITE_META = os.environ.get("OVERWRITE_META", False)
NUM_RETRY = 3

ETHERSCAN_API_KEY = os.environ.get("ETHERSCAN_API_KEY", None)


def result_dest(addr):
    return CONTRACTS_DIR / (f"{addr}{EXTENSION}")


def query_etherscan(contract_address):
    log.info(f"fetching for contract {contract_address}")
    retries = 0

    error = ""
    while retries < NUM_RETRY:

        url = ETHERSCAN_API_TEMPLATE.format(address=contract_address,
                                            key=ETHERSCAN_API_KEY)
        resp = requests.get(url)

        if resp.status_code != 200:
            log.error(
                f"Querying {contract_address} failed. Status code: {resp.status_code}"
            )
            error = str(resp.status_code)

        if (resp.json()["status"] == "0"
                or not resp.json()["result"][0]["SourceCode"]):
            log.warning(
                f"Failed to acquire source code of contract {contract_address}. Response: {resp.json()}"
            )
            error = resp.json()["result"]

        retries += 1
        if error and retries < NUM_RETRY:
            log.debug(f"Retrying #{retries}...")

    if error:
        with open(FAILED_LIST, "a", encoding="utf-8") as f:
            print(f"{contract_address},\"{error}\"", file=f)
        return

    result_json = resp.json()["result"][0]

    source = result_json['SourceCode']
    save_source(contract_address, source)

    del result_json['SourceCode']
    save_metadata(contract_address, result_json)


def save_source(contract_addr, source):
    solpath = CONTRACTS_DIR / f"{contract_addr}.sol"
    if solpath.exists():
        log.warning("source already exists saved")
        return

    with solpath.open("w") as f:
        f.write(source)


def save_metadata(contract_addr, result_json):
    """ Save meta data that excludes the source solidity code """
    solpath = result_dest(contract_addr)
    verbose_solpath = f"{str(solpath)[:-5]}.verbose.json"

    verbose_parameters = [
        "EVMVersion", "Library", "LicenseType", "Proxy", "Implementation",
        "SwarmSource"
    ]

    write_json(verbose_solpath, result_json)

    for param in verbose_parameters:
        if param in result_json:
            del result_json[param]
    write_json(solpath, result_json)


def write_json(solpath, result_json):
    with open(solpath, "w+", encoding="utf-8") as f:
        # put into a list for compatibility to analysis scripts
        j = [result_json]
        json.dump(j, f, indent=4)


if __name__ == "__main__":
    logging.basicConfig(level=logging.DEBUG)
    coloredlogs.install(level="DEBUG")
    if not ETHERSCAN_API_KEY:
        if len(sys.argv) < 3:
            log.error(
                "must provide etherscan api key either as env var or argv[2]")
            sys.exit(-1)
        ETHERSCAN_API_KEY = sys.argv[2]

    contract_addresses = []
    if sys.argv[1] == "-":
        contract_addresses = list(map(lambda s: s.strip(), sys.stdin.readlines()))
    else:
        with open(sys.argv[1]) as f:
            contract_addresses = list(map(lambda s: s.strip(), f.readlines()))

    if not os.path.exists(FAILED_LIST):
        with open(FAILED_LIST, "w") as f:
            print('"contract_address","error"', file=f)

    for addr in contract_addresses:
        solpath = result_dest(addr)
        if solpath.exists():
            log.info(f"{solpath} already exists!")
            if not OVERWRITE_META:
                continue
        query_etherscan(addr)
