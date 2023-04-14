#!/usr/bin/env python
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

import argparse
import datetime
import hashlib
import json
import logging
import os
import signal
import sqlite3
import sys
import tarfile
from pathlib import Path
from time import monotonic_ns, sleep

from .builder import create_state_build
from .dump_state_from_geth import URL as GETH_URL_DEFAULT
from .dump_state_from_geth import (exec_rpc_method, get_balance, get_code,
                                   get_code_and_hash, get_geth_blocknumber,
                                   set_geth_url, update_config_to_blocknumber)
from .fuzzer import launch_fuzzer
from .main import (EFCF_BUILD_CACHE, EFCF_FUZZ_DIR, EFCF_INSTALL_DIR, EVM_PATH,
                   find_cached_build)
from .utils import (existing_path, exit_with, find_fuzz_dir_candidate, log,
                    loge, logw, normalize_ethereum_address, realpath,
                    set_log_level)
"""
TODO:

* properly handle fuzzing contracts with increased timeout / previous seeds
* ...but only if there is nothing else to do, maybe?
"""

RAISE_INTERRUPT = False
STOP_FUZZ_LOOP = False
LATEST_BLOCK_WINDOW = 1024


def looks_like_eoa(address, number="latest"):
    address = normalize_ethereum_address(address)
    for i in range(3):
        try:
            code = get_code(address, number=number)
            balance = get_balance(address, number=number)
            if len(code) > 0 and code != "0x":
                return False
            else:
                if balance > 0:
                    return True
                else:
                    # hmmm? what does this mean? maybe a contract that is being constructed?
                    return True
        except ValueError as e:
            if i == 2:
                logw(f"failed to look up address {address} due to {e!r}")
                raise
            else:
                logw(f"failed to look up address {address} due to {e!r};",
                     "try again in a second")
                sleep(1)


def fetch_latest_window():
    contracts = {}
    eoas = set()

    res, err = exec_rpc_method("eth_getBlockByNumber", ["latest", False])
    if not res or err:
        loge(f"failed to get latest block from eth node - {err!s}")
        return (None, None)
    blocknum = int(res['number'], 0)
    timestamp = datetime.datetime.fromtimestamp(int(res['timestamp'], 0))

    if blocknum < LATEST_BLOCK_WINDOW:
        loge(
            f"block number {blocknum} smaller than block range analysis window {LATEST_BLOCK_WINDOW}"
        )
        return (None, None)

    for bn in range(blocknum - LATEST_BLOCK_WINDOW, blocknum):
        log(f"fetching block number {bn}", level=logging.DEBUG)
        res, err = exec_rpc_method("eth_getBlockByNumber", [hex(bn), True])
        if not res or err:
            logw(f"failed to get block {bn} from eth node - {err!s}")
            continue

        log("processing",
            len(res['transactions']),
            "tx in block",
            bn,
            level=logging.DEBUG)
        for tx in res['transactions']:
            if 'to' not in tx or not tx['to'] or tx['to'] == "0x":
                # create transaction - ignore
                continue
            receiver = normalize_ethereum_address(tx['to'])
            if receiver in eoas:
                continue
            if receiver in contracts:
                contracts[receiver].append((tx['hash'], int(tx['value'],
                                                            0), bn))
            else:
                if looks_like_eoa(receiver):
                    eoas.add(receiver)
                else:
                    contracts[receiver] = [(tx['hash'], int(tx['value'],
                                                            0), bn)]

    contract_queue = sorted([(k, sum(i[1]
                                     for i in v), max(bn
                                                      for (_, _, bn) in v) - 1)
                             for k, v in contracts.items()],
                            key=lambda x: x[1],
                            reverse=True)

    return (blocknum, timestamp, contract_queue)


def fetch_newly_deployed():
    contracts = {}

    res, err = exec_rpc_method("eth_getBlockByNumber", ["latest", False])
    if not res or err:
        loge(f"failed to get latest block from eth node - {err!s}")
        return (None, None, None)
    blocknum = int(res['number'], 0)
    timestamp = datetime.datetime.fromtimestamp(int(res['timestamp'], 0))

    if blocknum < LATEST_BLOCK_WINDOW:
        loge(
            f"block number {blocknum} smaller than block range analysis window {LATEST_BLOCK_WINDOW}"
        )
        return (None, None, None)

    for bn in range(blocknum, blocknum - LATEST_BLOCK_WINDOW, -1):
        log(f"fetching block number {bn}", level=logging.DEBUG)
        res, err = exec_rpc_method("eth_getBlockByNumber", [hex(bn), True])
        if not res or err:
            logw(f"failed to get block {bn} from eth node - {err!s}")
            continue

        log("processing",
            len(res['transactions']),
            "tx in block",
            bn,
            level=logging.DEBUG)
        for tx in res['transactions']:
            if 'to' not in tx or not tx['to'] or tx['to'] == "0x":
                # create transaction - ignore
                log("found create transaction with hash",
                    tx['hash'],
                    level=logging.DEBUG)
                if not tx['input'] or tx['input'].strip() == "0x":
                    log(
                        "skipping odd transaction with both empty 'to' and empty 'input'. hash: ",
                        tx['hash'])
                    continue
                res, err = exec_rpc_method("eth_getTransactionReceipt",
                                           [tx['hash']])
                if not res or err:
                    loge(f"failed to get latest block from eth node - {err!s}")
                    continue

                if 'contractAddress' not in res:
                    loge("no 'contractAddress' found in tx receipt:",
                         json.dumps(res, indent=2))
                    continue

                contract_addr = res['contractAddress']
                if contract_addr in contracts:
                    logw(
                        "wtf? encountered two create transactions for a single contract? weird af"
                    )
                    continue

                contract_balance = get_balance(contract_addr, number='latest')
                contracts[contract_addr] = (bn, contract_balance)

    contracts = sorted([(k, v[1], v[0]) for k, v in contracts.items()],
                       key=lambda x: (x[2], x[1]),
                       reverse=True)

    return (blocknum, timestamp, contracts)


def parse_args():
    parser = argparse.ArgumentParser()
    # ========================================================================
    g = parser.add_argument_group("EVM Environment")
    g.add_argument(
        "--over-approximate-all-calls",
        action="store_true",
        help=
        "[Beware of False Alarms] allow the fuzzer to over-approximate the return values of all external calls"
    )

    g.add_argument(
        "--ignore-initial-ether",
        choices=['y', 'n'],
        default='y',
        help=
        "whether to allow a force-send of Ether to the target before executing the testcase."
    )

    # ========================================================================
    g = parser.add_argument_group("Live State Export")
    g.add_argument(
        "--geth-url",
        default=GETH_URL_DEFAULT,
        type=str,
        help=
        "URL of go-ethereum or erigon full/archive node. Endpoint must support the `debug_storageRangeAt` API call."
    )
    g.add_argument("--geth-rate-limit",
                   action="store_true",
                   help="avoid spamming geth with too many requests at once "
                   " (useful only when doing many exports in paralllel)")
    g.add_argument(
        "--include-address-deps",
        choices=['y', 'n'],
        default='y',
        # type=bool_choice,
        help=
        "recursively scan storage of exported contracts for address dependencies and add them to the live-state export",
    )

    g.add_argument(
        "--include-mapping-deps",
        choices=['y', 'n'],
        default='n',
        help="Also include address deps stored in mappings or dynamic arrays.")

    g.add_argument(
        "--dict-max-length",
        type=int,
        default=4096,
        help="maximum number of dictionary entries in the combined dictionary")

    # ========================================================================
    g = parser.add_argument_group("Contract Selection")
    g.add_argument("--block-window",
                   type=int,
                   default=LATEST_BLOCK_WINDOW,
                   help="window of latest N blocks to analyze")

    g.add_argument("--selection-strategy",
                   choices=["top_received", "newly_deployed"],
                   help="How to select contracts for fuzzing")

    g.add_argument("--max-time-per-window",
                   type=lambda x: datetime.timedelta(hours=int(x, 0)),
                   help="hours that are maximally spent per block window")

    g.add_argument(
        "--skip-window-if-older-than",
        type=(lambda x: datetime.timedelta(hours=int(x, 0))),
        default=datetime.timedelta(hours=24),
        help=
        "in hours: if still analyzing with a starting block that is older than this - skip to the newest"
    )

    # ========================================================================
    g = parser.add_argument_group("Bug Oracles")
    g.add_argument("--ignore-leaking",
                   action="store_true",
                   help='[DEPRECATED] now default')
    g.add_argument(
        "--report-leaking-ether",
        action="store_true",
        help=("report leaking ether issues (aka. 'prodigal' contracts), "
              "where a contract sends ether to some unknown address that has "
              "not yet interacted with the contracts. "
              "Beware: many false alarms with Token-like contracts"))
    g.add_argument(
        "--report-dos-selfdestruct",
        action="store_true",
        help=
        "report selfdestructs also if they do not result in (potential) ether gains."
    )

    # ========================================================================
    g = parser.add_argument_group("Fuzzing")
    g.add_argument("-t",
                   "--timeout",
                   default=600,
                   type=int,
                   help="total fuzzing campaign timeout in seconds")
    g.add_argument("--timeout-upper-bound",
                   default=(12 * 60 * 60),
                   type=int,
                   help="the fuzzer timeout will be adapted if the target has been fuzzed before. this is the upper bound for fuzzer timeout in seconds.")
    g.add_argument(
        "-T",
        "--exec-timeout",
        default=None,
        help=
        "execution timeout for a single testcase (passed directly to base-fuzzer)"
    )
    # g.add_argument(
    #     "-C",
    #     "--until-crash",
    #     action="store_true",
    #     help="run the fuzzer until the first crash / bug is discovered")
    g.add_argument("--cores",
                   type=int,
                   help="number of cores to use for fuzzing")
    g.add_argument("--fuzzmode",
                   choices=["2AT", "monly", "none"],
                   default="2AT",
                   help="EF/CF fuzzing configuration mode")
    g.add_argument(
        "--cleanup-kills",
        choices=('y', 'n'),
        default='y',
        # type=bool_choice,
        help="try to pkill -9 potential remaining processes")
    # ========================================================================
    g = parser.add_argument_group("Builds")
    g.add_argument("--ignore-cached-builds",
                   action="store_true",
                   help="Ignore files in the build cache.")

    # ========================================================================
    g = parser.add_argument_group("Install Paths")
    g.add_argument("--install-dir",
                   type=existing_path,
                   default=EFCF_INSTALL_DIR)
    g.add_argument("--build-cache",
                   type=existing_path,
                   default=EFCF_BUILD_CACHE)
    g.add_argument("--eevm-path", type=existing_path, default=EVM_PATH)
    g.add_argument("--fuzz-dir", type=Path, default=EFCF_FUZZ_DIR)

    # ========================================================================
    parser.add_argument(
        "-o",
        "--out",
        type=Path,
        default=Path("./cont_fuzzing_runs/"),
        help="path to a directory, which stores the fuzzing results")

    parser.add_argument(
        "--remove-out-on-failure",
        choices=('y', 'n'),
        default='n',
        # type=bool_choice,
        help="remove out file on failure.")

    parser.add_argument(
        "--results-file",
        type=str,
        default="continous-results.db",
        help="filename of the results file for continous fuzzing")

    parser.add_argument("-v",
                        "--verbose",
                        action="store_true",
                        help="enable verbose logging")
    parser.add_argument(
        "--quiet",
        action="store_true",
        help="disable verbose logging and suppress fuzzer output")

    parser.add_argument(
        "--skip-already-fuzzed",
        choices=['y', 'n'],
        default='y',
        help="whether to fuzz a contract at a address a second time")

    parser.add_argument(
        "--skip-fuzzing-code-duplicates",
        choices=['y', 'n'],
        default='y',
        help=
        "whether to fuzz a contract at a different address, but same code, a second time"
    )
    parser.add_argument(
        "--lock-contract-anyway",
        choices=['y', 'n'],
        default='y',
        help="avoid running two parallel fuzzing runs on the same contract",
    )

    # ========================================================================
    args = parser.parse_args()

    # sanitize/update/fixup parsed args
    args.install_dir = realpath(args.install_dir)
    args.build_cache = realpath(args.build_cache)
    args.eevm_path = realpath(args.eevm_path)
    args.fuzz_dir = realpath(args.fuzz_dir)

    args.remove_out_on_failure = (args.remove_out_on_failure == 'y')
    args.cleanup_kills = (args.cleanup_kills == 'y')
    args.include_address_deps = (args.include_address_deps == 'y')
    args.include_mapping_deps = (args.include_mapping_deps == 'y')
    args.ignore_initial_ether = (args.ignore_initial_ether == 'y')

    args.skip_already_fuzzed = (args.skip_already_fuzzed == 'y')
    args.skip_fuzzing_code_duplicates = (
        args.skip_fuzzing_code_duplicates == 'y')
    args.lock_contract_anyway = (args.lock_contract_anyway == 'y')

    args.deploy_args = None
    args.create_tx_input = None

    args.until_crash = True

    # args.remove_out_on_failure = False
    args.compress_builds = False
    args.disable_detectors = False

    args.properties = None
    args.assertions = None
    args.sol_assertions = None
    args.event_assertions = None
    args.event_assertions_list = None
    args.event_assertions_target_only = False
    args.multi_target = False
    args.multi_target_addresses = []

    args.compute_evm_cov = True
    args.generate_cov_plots = False

    args.print_progress = False

    # TODO: set elsewhere?
    args.seed_files = None

    return args


def launch_fuzzer_for(blocknum, contract_addr, code, code_hash, score, config):
    global RAISE_INTERRUPT
    RAISE_INTERRUPT = True
    # if we receive a SIGTERM, we tell the signal handler to raise an exception
    # during any of the following code, which prepares the fuzzing run. Here we
    # just want to return to the caller early. However, once we launch the
    # fuzzer we want to wait until the fuzzer exited to gather preliminary
    # results and stats.

    target = normalize_ethereum_address(contract_addr)

    log(f"processing {target} at {blocknum} with score {score}")

    code_len = len(code)
    if code_len > 2:
        pass
    else:
        logw(
            f"skipping! weird issue, tried to analyze contract {target}, but has no code (len {code_len}) at #{blocknum}; tx value sum {score}"
        )
        raise Exception("target without code")

    # hash configuration
    hkey = target.encode('utf-8')
    h = hashlib.blake2b(hkey, digest_size=16)
    for v in [
            config.include_address_deps, config.include_mapping_deps, blocknum
    ]:
        h.update(str(v).encode('utf-8'))
    hashed = h.hexdigest()

    blocknum = get_geth_blocknumber()
    buildtype = f"state_b{blocknum}"
    build_exists, build = find_cached_build(config, target, buildtype, hashed)
    if not build_exists:
        r = create_state_build(config, target, [target], build,
                               config.eevm_path)
        if not r:
            loge(f"build failure - skipping {target} at {blocknum}")
            raise Exception("build failed")

    def make_path(i):
        return (realpath(config.out) / str(code_hash) / str(target) /
                str(blocknum) / f"{i}_result.tar.xz")

    i = 0
    outpath = make_path(i)
    while outpath.exists():
        i += 1
        outpath = make_path(i)

    os.makedirs(config.fuzz_dir, exist_ok=True)
    RAISE_INTERRUPT = False
    (res, exit_code, stats) = launch_fuzzer(build, config, outpath,
                                            realpath(config.fuzz_dir))
    if res:
        log(f"fuzzer ran for {target} at {blocknum}")
    else:
        loge(f"fuzzer failed for {target} at {blocknum}")
        # we do not raise an exception here, since if the script is run with
        # --remove-out-on-failure=n, then we can use this to debug.

    return (res, outpath, exit_code, stats)


def sig_interrupt_handler(signum, frame):
    global STOP_FUZZ_LOOP
    if not STOP_FUZZ_LOOP:
        logw("Stopping Fuzz Worker - Received signal",
             signal.Signals(signum).name, "(", signal.strsignal(signum), ")")
        STOP_FUZZ_LOOP = True
        pgid = os.getpgid(0)
        log(f"notifying process group (pgid={pgid}, signum={signum})")
        os.killpg(pgid, signum)
        sleep(1)
    # if the fuzzer is currently running, then we wait until the fuzzer is
    # done. Since we forward the signal to the whole process group, the fuzzer
    # process (i.e., afl-fuzz) will receive the signal and terminate early.
    # Otherwise we need to raise an exception, s.t., the execution does not
    # continue unnecesarily. However, if something else is running, e.g., the
    # clang build or evm2cpp, we want to exit early and skip all those steps.
    global RAISE_INTERRUPT
    if RAISE_INTERRUPT:
        raise KeyboardInterrupt(
            f"Interrupt due to signal {signal.Signals(signum).name}")


DB = None


def load_results(config):
    global DB
    path = realpath(config.out) / config.results_file
    if not path.parent.exists():
        path.parent.mkdir(exist_ok=True, parents=True)
    log("opening database", path, level=logging.DEBUG)
    DB = sqlite3.connect(str(path))
    DB.row_factory = sqlite3.Row

    try:
        with DB:
            DB.executescript("""
CREATE TABLE bugs(
    code_hash text,
    address text,
    description text,
    confirmed text
);
CREATE TABLE current_fuzzers(
    address text,
    code_hash text,
    running integer,
    unique(address,code_hash)
);
CREATE TABLE runs(
    address text,
    code_hash text,
    blocknum integer,
    success boolean,
    reason text,
    path text,
    bugcount integer,
    cov real,
    timeout integer,
    until_crash boolean,
    cores integer,
    fuzztime text,
    timestamp text,
    exitcode integer,
    avg_eps real,
    total_execs integer
);
""")
    except sqlite3.OperationalError:
        log("using existing database", level=logging.DEBUG)


def add_result(config,
               contract_addr,
               code_hash=None,
               success=False,
               reason=None,
               blocknum=None,
               path=None,
               bugs=None,
               cov=None,
               time=None,
               stats=None,
               exit_code=None):
    if blocknum is not None:
        if isinstance(blocknum, str):
            blocknum = int(blocknum, 0)
    cores = 1
    if config.cores is not None:
        cores = int(config.cores)
    avg_eps = None
    total_execs = None
    if stats:
        avg_eps = stats.avg_eps
        total_execs = int(stats.total_execs)

    global DB
    with DB:
        DB.execute(
            """
INSERT INTO runs (
address,
code_hash,
blocknum,
success,
reason,
path,
bugcount,
cov,
timeout,
until_crash,
cores,
fuzztime,
timestamp,
exitcode,
avg_eps,
total_execs
) values (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?);""",
            (contract_addr, code_hash, blocknum, success, reason,
             str(path) if path else path, len(bugs) if bugs else 0, cov,
             config.timeout, config.until_crash, cores, time,
             datetime.datetime.now(), exit_code, avg_eps, total_execs))

    with DB:
        if bugs:
            cur = DB.cursor()
            gen = ((code_hash, contract_addr, b, "unknown") for b in bugs)
            cur.executemany(
                """
insert into bugs (
    code_hash,
    address,
    description,
    confirmed
) values (?, ? ,?, ?);""", gen)


def check_and_set_running(addr, code_hash, allow_concurrent=True):
    with DB:
        cur = DB.cursor()
        running = 0
        r = cur.execute(
            "select running from current_fuzzers where address = ? and code_hash = ?",
            (addr, code_hash)).fetchone()
        if r:
            running = int(r[0])
            if not allow_concurrent and running > 0:
                return False
            cur.execute(
                "update current_fuzzers set running = running + 1 where address = ? and code_hash = ?",
                (addr, code_hash))
        else:
            cur.execute("insert into current_fuzzers values (?, ?, ?)",
                        (addr, code_hash, 1))

        # do a bit of maintenance...
        cur.execute("delete from current_fuzzers where running == 0")

    return True


def set_finished(addr, code_hash):
    with DB:
        cur = DB.cursor()
        cur.execute(
            "update current_fuzzers set running = running - 1 where address = ? and code_hash = ?",
            (addr, code_hash))


def get_stats_for(contract_addr):
    has_bug = False
    timeout = 0
    last_run_path = None

    # last_run_num = -1
    # if contract_addr in RESULTS and RESULTS[contract_addr]:
    #     for bnum, res in RESULTS[contract_addr].items():
    #         if res:
    #             if bnum and bnum != 'null' and isinstance(bnum, str):
    #                 bnum = int(bnum, 0)
    #             for r in res:
    #                 has_bug = has_bug or r.get("bugs", [])
    #                 timeout = max(timeout, r.get("timeout", 0))
    #             longest = max(res,
    #                           key=lambda x: -1
    #                           if not x['success'] else x.get("timeout", 0))
    #             if bnum and bnum > last_run_num:
    #                 if "path" in longest and longest['path']:
    #                     last_run_path = longest['path']
    #                     last_run_num = bnum
    global DB
    with DB:
        cur = DB.cursor()
        has_bug = cur.execute(
            "select count(*) from runs where address = ? and bugcount > 0",
            (contract_addr, )).fetchone()[0] > 0
        row = cur.execute(
            """select * from runs
where address = ? and success > 0 and path is not null
order by blocknum, timeout desc limit 1""", (contract_addr, )).fetchone()
        if row:
            timeout = row['timeout']
            last_run_path = row['path']

    return (has_bug, timeout, last_run_path)


def code_duplicate_was_fuzzed(contract_addr,
                              code_hash,
                              only_successfully=False):
    global DB
    with DB:
        cur = DB.cursor()
        if only_successfully:
            return cur.execute(
                "select count(*) from runs where address != ? and code_hash = ?",
                (contract_addr, code_hash)).fetchone()[0] > 0
        else:
            return cur.execute(
                "select count(*) from runs where address != ? and code_hash = ? and success = true",
                (contract_addr, code_hash)).fetchone()[0] > 0


def main():
    config = parse_args()
    log("launching EF/CF - continous fuzzing")
    if config.verbose and not config.quiet:
        set_log_level(logging.DEBUG)
        log("enabled verbose logging", level=logging.DEBUG)

    if config.geth_url:
        if not set_geth_url(config.geth_url):
            exit_with(1, (
                "no working go-etherum (compatible) node available at given url: "
                + repr(config.geth_url)))

    # load previously stored results
    load_results(config)

    # signal.signal(signal.SIGINT, sig_interrupt_handler)
    signal.signal(signal.SIGTERM, sig_interrupt_handler)

    global LATEST_BLOCK_WINDOW
    LATEST_BLOCK_WINDOW = config.block_window

    iteration = 0

    global RAISE_INTERRUPT
    global RESULTS
    global STOP_FUZZ_LOOP
    while not STOP_FUZZ_LOOP:
        log(f"fetching latest block window (iteration {iteration})")
        window_start = monotonic_ns()
        blocknum, timestamp, contracts = None, None, None
        try:
            RAISE_INTERRUPT = True
            if config.selection_strategy == "top_received":
                blocknum, timestamp, contracts = fetch_latest_window()
            elif config.selection_strategy == "newly_deployed":
                blocknum, timestamp, contracts = fetch_newly_deployed()
            else:
                exit_with(
                    1, "invalid/unknown selection strategy: " +
                    repr(config.selection_strategy))
        except ValueError:
            secs = 30
            logw("encountered exception; waiting for",
                 secs,
                 "seconds; then trying again",
                 exc_info=True)
            sleep(secs)
            continue
        except KeyboardInterrupt:
            pass
        finally:
            RAISE_INTERRUPT = False

        if STOP_FUZZ_LOOP:
            break

        if blocknum is None:
            secs = 60
            logw("sleeping for", secs, "seconds; then trying again")
            sleep(secs)
            continue

        config.live_state_blocknumber = blocknum

        log("processing block window from",
            blocknum, "to", blocknum - LATEST_BLOCK_WINDOW, "with",
            len(contracts), "contracts")
        update_config_to_blocknumber(blocknum)

        processed = 0
        fuzzed = 0
        # we assume contracts list is already sorted
        for contract_addr, score, _ in contracts:
            if STOP_FUZZ_LOOP:
                break

            contract_addr = normalize_ethereum_address(contract_addr)
            r = None
            outpath = None
            processed += 1
            try:
                RAISE_INTERRUPT = True
                has_known_bug, biggest_timeout, last_run = get_stats_for(
                    contract_addr)
                code, code_hash = get_code_and_hash(contract_addr, blocknum)
            except KeyboardInterrupt:
                pass
            except ValueError as e:
                loge(f"failed to process {contract_addr} due to error {e!r}",
                     exc_info=True)
                continue
            finally:
                RAISE_INTERRUPT = False

            if STOP_FUZZ_LOOP:
                break

            if not code or not code_hash:
                loge("failed to fetch code/code_hash for address",
                     contract_addr, "-> skipping")
                continue

            code_hash = code_hash.hex()

            log("processing contract", contract_addr)

            if has_known_bug:
                log("skipping fuzzing of contract", contract_addr,
                    "with previous findings (crashes)")
                continue

            if last_run is not None and config.skip_already_fuzzed:
                log("skipping already fuzzed contract", contract_addr)
                continue

            if (config.skip_fuzzing_code_duplicates
                    and code_duplicate_was_fuzzed(contract_addr, code_hash)):
                log("skipping already fuzzed contract", contract_addr,
                    "with duplicated code hash", code_hash)
                continue

            if config.timeout < biggest_timeout:
                config.timeout = min(biggest_timeout + biggest_timeout / 2,
                                     config.timeout_upper_bound)

            if last_run:
                last_run = realpath(last_run)
                if last_run.exists() and last_run.is_dir():
                    for aflfuzzid in ["default", "m0", "c1"]:
                        p = (last_run / aflfuzzid / "queue")
                        if p.exists() and p.is_dir():
                            log("seeding from last run", last_run)
                            config.seed_files = str(p)

            if STOP_FUZZ_LOOP:
                break

            allow_concurrent = True
            if (config.skip_fuzzing_code_duplicates
                    or config.skip_already_fuzzed
                    or config.lock_contract_anyway):
                allow_concurrent = False
            if not check_and_set_running(contract_addr, code_hash,
                                         allow_concurrent):
                logw("skipping contract due to concurrent fuzzing campaign")
                continue
            r = None
            outpath = None
            exit_code = None
            stats = None
            try:
                if STOP_FUZZ_LOOP:
                    break

                log("launching fuzzer for", contract_addr)
                (r, outpath, exit_code,
                 stats) = launch_fuzzer_for(blocknum, contract_addr, code,
                                            code_hash, score, config)
            except KeyboardInterrupt:
                logw("fuzzer got interrupted; stopping now")
                STOP_FUZZ_LOOP = True
                break
            except Exception as e:
                loge(
                    f"encountered critical error while fuzzing {contract_addr} @ b{blocknum}: {e!r}",
                    exc_info=True)
                add_result(config,
                           contract_addr,
                           success=False,
                           reason=repr(e),
                           code_hash=code_hash,
                           path=outpath,
                           blocknum=blocknum,
                           stats=stats,
                           exit_code=exit_code)
                continue
            finally:
                set_finished(contract_addr, code_hash)
            if r:
                fuzzed += 1
                bugs = None
                cov = None
                time = None

                if outpath.is_file() and tarfile.is_tarfile(outpath):
                    with tarfile.open(outpath) as tf:
                        try:
                            buginfo = tf.getmember("./bugs")
                            bugs = tf.extractfile(
                                buginfo).read().decode().strip()
                            if bugs:
                                bugs = bugs.splitlines()
                            else:
                                bugs = None
                        except KeyError:
                            logw("no `bugs` file in results tarball")
                            bugs = None

                        try:
                            covinfo = tf.getmember(
                                "./coverage-percent-all.evmcov")
                            cov = float(
                                tf.extractfile(
                                    covinfo).read().decode().strip())
                        except KeyError:
                            logw(
                                "no `coverage-percent-all.evmcov` file in results tarball"
                            )
                        except ValueError as e:
                            logw("could not determine coverage", repr(e))
                            cov = None

                        try:
                            timeinfo = tf.getmember("./afl.time")
                            for line in tf.extractfile(timeinfo).readlines():
                                line = line.decode().strip().lower()
                                if "wall" in line and "time" in line:
                                    log("fuzzer ran for",
                                        repr(line),
                                        level=logging.DEBUG)
                                    line = line.split("): ")
                                    if len(line) >= 2:
                                        time = line[-1].strip()
                                        break
                        except KeyError:
                            logw("no `bugs` file in results tarball")
                            time = None

                elif outpath.is_dir():
                    bugpath = realpath(outpath) / "bugs"
                    if bugpath.exists():
                        with bugpath.open() as f:
                            bugs = f.read().strip()
                        if bugs:
                            bugs = bugs.splitlines()
                        else:
                            bugs = None
                    covpath = realpath(outpath) / "coverage-percent-all.evmcov"
                    if covpath.exists():
                        with covpath.open() as f:
                            try:
                                cov = float(f.read().strip())
                            except ValueError as e:
                                logw("could not determine coverage", repr(e))
                                cov = None
                    timepath = realpath(outpath) / "afl.time"
                    if timepath.exists():
                        with timepath.open() as f:
                            for line in f.readlines():
                                line = line.strip().lower()
                                if "wall" in line and "time" in line:
                                    log("fuzzer ran for",
                                        repr(line),
                                        level=logging.DEBUG)
                                    line = line.split("): ")
                                    if len(line) >= 2:
                                        time = line[-1].strip()
                                        break

                add_result(config,
                           contract_addr,
                           success=True,
                           blocknum=blocknum,
                           path=outpath,
                           bugs=bugs,
                           cov=cov,
                           code_hash=code_hash,
                           time=time,
                           stats=stats,
                           exit_code=exit_code)
                lenbugs = 0
                if bugs:
                    lenbugs = len(bugs)
                log(f"finished fuzzing run for {contract_addr} with {lenbugs} and {cov} coverage"
                    )
            else:
                add_result(config,
                           contract_addr,
                           code_hash=code_hash,
                           success=False,
                           reason="fuzzer failed",
                           path=outpath,
                           blocknum=blocknum,
                           stats=stats,
                           exit_code=exit_code)

            if STOP_FUZZ_LOOP:
                logw("received stop signal; stopping processing of current window",
                     f"(blocknum {blocknum} from {timestamp})")
                break

            if config.max_time_per_window:
                now = monotonic_ns()
                diff_usec = int((now - window_start) // 1000)
                diff = datetime.timedelta(microseconds=diff_usec)
                if diff > config.max_time_per_window:
                    log(f"stopping processing current window after {diff} (larger than {config.max_time_per_window})"
                        )
                    break

            if config.skip_window_if_older_than and timestamp:
                diff = datetime.datetime.now() - timestamp
                if diff > config.skip_window_if_older_than:
                    log("stopping currently processing starting block",
                        str(blocknum), "from", str(timestamp), "older than",
                        str(config.skip_window_if_older_than))
                    break

        log(f"processed window -> fuzzed {fuzzed} of {processed} processed contracts ({len(contracts)} in window)"
            )

        if fuzzed == 0 and not STOP_FUZZ_LOOP:
            wait_for_sec = 240
            logw(
                f"fuzzed nothing in this iteration. waiting for {wait_for_sec} seconds."
            )
            sleep(wait_for_sec)

    DB.close()
    log("so long, and thanks for all the fuzz")
    sys.exit(0)
