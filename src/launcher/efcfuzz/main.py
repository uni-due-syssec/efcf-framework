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


# stdlib imports
import argparse
import hashlib
import logging
import os
import subprocess as sp
import sys
from pathlib import Path

# local imports
from .builder import (DEFAULT_MULTI_ADDRLIST, compile_source,
                      create_runtime_build, create_state_build)
from .dump_state_from_geth import URL as GETH_URL_DEFAULT
from .dump_state_from_geth import (get_geth_blocknumber, set_geth_url,
                                   update_config_to_blocknumber,
                                   update_config_to_preset)
from .ethbmc_integration import make_seeds_from_ethbmc_zip
from .fuzzer import launch_fuzzer
from .utils import (check_and_extend_path, existing_path, exit_with,
                    find_fuzz_dir_candidate, is_git_dir, log, logw,
                    looks_like_address, normalize_ethereum_address, pushdir,
                    realpath, run, set_log_level, sudo)

EXIT_SUCCESS = 0
EXIT_FUZZ_FAILURE = 3
EXIT_BUILD_FAILURE = 2
EXIT_INVALID_PARAMS = -1

EVM_DIR = None

EFCF_INSTALL_DIR = Path(os.environ.get("EFCF_INSTALL_DIR", "./"))
EFCF_BUILD_CACHE = Path(
    os.environ.get("EFCF_BUILD_CACHE", "./efcf-build-cache/"))
EFCF_FUZZ_DIR = Path(os.environ.get("EFCF_FUZZ_DIR",
                                    find_fuzz_dir_candidate()))
EVM_PATH = Path(os.environ.get("EVM_PATH", EFCF_INSTALL_DIR / "src" / "eEVM"))

DEFAULT_BUILD_FORMAT = "{name}.{btype}{hashed}.fuzz.build"

__geth_init_called = False


def geth_init(args):
    """
    helper for lazy geth initialization
    """
    global __geth_init_called
    if __geth_init_called:
        return

    if args.geth_url:
        if not set_geth_url(args.geth_url):
            exit_with(EXIT_INVALID_PARAMS, "no go-etherum node available")

    if args.live_state_blocknumber:
        if not update_config_to_blocknumber(args.live_state_blocknumber):
            exit_with(EXIT_INVALID_PARAMS,
                      "failed to update config according to block number")
    elif args.geth_preset:
        if not update_config_to_preset(args.geth_preset):
            exit_with(EXIT_INVALID_PARAMS,
                      "failed to update config according to geth preset")
    __geth_init_called = True


def bool_choice(s):
    if s is None:
        return None
    if s == 'y':
        return True
    elif s == 'n':
        return False
    raise ValueError(f"invalid choice {s!r}")


def get_yn_env(s, default):
    r = os.environ.get(s, default)
    if r and r[0] in ('y', 'Y', '1'):
        return 'y'
    else:
        return 'n'


def valid_timespan(s):
    if isinstance(s, int):
        return s
    if not s:
        raise ValueError(f"invalid timespan integer {s!r}")
    s = s.strip()
    if s == "forever":  # a bit of a hack but ¯\_(ツ)_/¯
        return (2**32) - 1
    try:
        return int(s, 0)
    except ValueError:
        if s[-1] == 'h':
            return int(s[:-1].strip(), 0) * 60 * 60
        elif s[-1] == 'm':
            return int(s[:-1].strip(), 0) * 60
        else:
            raise


def get_build_cache(args):
    buildcache = realpath(args.build_cache)

    if not buildcache.exists():
        os.makedirs(buildcache, exist_ok=True)

    return buildcache


def parse_args():
    parser = argparse.ArgumentParser()

    # ========================================================================
    reqs = parser.add_mutually_exclusive_group(required=True)

    reqs.add_argument("--source",
                      nargs="+",
                      type=existing_path,
                      help="Solidity smart contract source code file (.sol).")
    reqs.add_argument(
        "--bin-runtime",
        type=existing_path,
        help="Smart contract runtime bytecode (.bin-runtime or .combined.json)."
    )
    reqs.add_argument(
        "--live-state",
        type=str,
        nargs='+',
        help=
        "Export live state of a set of contracts - a list of contract addresses to export from an full/archive go-ethereum node"
    )
    reqs.add_argument(
        '--force-use-build',
        help='force the use of an existing build instead of rebuilding.',
        type=existing_path)
    reqs.add_argument("--version", action="store_true", help="print version")

    # ========================================================================
    g = parser.add_argument_group("EVM Environment")
    g.add_argument(
        "--bin-deploy",
        type=existing_path,
        help=
        "Constructor byteocde (.bin file). Default: guessed based on filename of bin-runtime file."
    )
    g.add_argument("--deploy-args",
                   type=str,
                   help="Encoded constructor arguments")
    g.add_argument(
        "--create-tx-input",
        type=str,
        help=
        "Copy-paste of create transaction (constructor code + encoded constructor arguments)"
    )
    g.add_argument("--name",
                   type=str,
                   help="name of the target smart contract")
    g.add_argument("--abi", type=existing_path, help="path to ABI file")
    g.add_argument(
        "--allow-creator-tx",
        action="store_true",
        help=
        "[Beware of False Alarms] allow transactions from the contract creator (no effect for live-state)"
    )
    g.add_argument(
        "--over-approximate-all-calls",
        action="store_true",
        help=
        "[Beware of False Alarms] allow the fuzzer to over-approximate the return values of all external calls"
    )

    g.add_argument(
        "--ignore-initial-ether",
        choices=('y', 'n'),
        default='n',
        help=
        "whether to allow a force-send of Ether to the target before executing the testcase."
    )

    # ========================================================================
    g = parser.add_argument_group("Live State Export")
    g.add_argument(
        "--live-state-target",
        type=str,
        help=
        "target address for live state exports (defaults to first address in list)"
    )
    g.add_argument(
        "--geth-preset",
        choices=['old', 'latest'],
        default='latest',
        help=
        "configuration preset for calling go-ethereum APIs - use `latest` block or a default `old` block state (at number 9069000)"
    )
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
    g.add_argument("--live-state-blocknumber",
                   type=int,
                   help='block number of live state import')
    g.add_argument(
        "--include-address-deps",
        choices=['y', 'n'],
        default='n',
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
        "--seed-from-ethbmc-attacks",
        type=existing_path,
        help=
        "Path to zip file containing ethbmc results with attacks under 'final_result/{address}.json' this overrides the --seed-files argument"
    )

    g.add_argument(
        "--dict-max-length",
        type=int,
        default=4096,
        help="maximum number of dictionary entries in the combined dictionary")

    g.add_argument("--multi-target",
                   choices=['y', 'n'],
                   default='n',
                   help="Enable multi-target fuzzing mode.")

    # ========================================================================
    g = parser.add_argument_group("Bug Oracles")
    g.add_argument(
        "--properties",
        type=existing_path,
        help=
        ("list of solidity property functions to check "
         "(formatted like the --hashes output of solc; must contain the 4-byte function selectors in hex)"
         ))
    g.add_argument(
        "--disable-detectors",
        action='store_true',
        help=
        "disable all built-in ether-based detectors. (i.e., everything except for properties)"
    )
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

    g.add_argument(
        "--assertions",
        action='store_true',
        help=
        "Report bugs on all kinds of assertion fails (solidity and event assertions)"
    )
    g.add_argument(
        "--sol-assertions",
        action='store_true',
        help=
        "Report testcases that return value of the form of a `Panic(X)` error."
    )
    g.add_argument(
        "--event-assertions",
        action='store_true',
        help=("Enable assertion events as bug oracles "
              "(i.e., report a bug on `emit AssertionFailed(...)`)"))
    g.add_argument(
        "--event-assertions-list",
        type=existing_path,
        help=
        ("list of event topics to check as part of the event-based bug oracle."
         ))
    g.add_argument(
        "--event-assertions-target-only",
        choices=['y', 'n'],
        default='y',
        help=
        "enable looking for event assertions everywhere or only in the target")

    # ========================================================================
    g = parser.add_argument_group("Fuzzing")
    g.add_argument(
        "-t",
        "--timeout",
        default="24h",
        type=valid_timespan,
        help=
        "total fuzzing campaign timeout in seconds (or minutes postfixed with 'm'; or hours postfixed with 'h')"
    )
    g.add_argument(
        "-T",
        "--exec-timeout",
        default=None,
        help=
        "execution timeout in seconds for a single testcase (passed directly to base-fuzzer) - usually auto-calibrated"
    )
    g.add_argument(
        "--print-progress",
        action='store_true',
        default=False,
        help="continously log fuzzing stats",
    )
    g.add_argument(
        "-C",
        "--until-crash",
        action="store_true",
        help="run the fuzzer until the first crash / bug is discovered")
    g.add_argument("--cores",
                   type=int,
                   help="number of cores to use for fuzzing",
                   default=int(os.environ.get("FUZZ_CORES", 1)))
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
    g.add_argument("--configure-system",
                   action="store_true",
                   help="temporarily configure system for fuzzing with AFL++")

    g.add_argument(
        "--seed-files",
        type=existing_path,
        help="Path to existing seed files (e.g., from prior fuzzing runs)")

    g.add_argument(
        "--compute-evm-cov",
        choices=('y', 'n'),
        default=get_yn_env("FUZZ_EVMCOV", 'y'),
        help="whether to compute evm-level basic block coverage in percent."
    )
    g.add_argument(
        "--generate-cov-plots",
        choices=('y', 'n'),
        default=get_yn_env("FUZZ_PLOT", 'n'),
        help="whether to automatically create coverage plots with afl-plot.")

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
    g = parser.add_argument_group("Builds")
    g.add_argument("--compress-builds",
                   choices=('y', 'n'),
                   default='n',
                   help="compress fuzzing builds")
    g.add_argument("--ignore-cached-builds",
                   action="store_true",
                   help="Ignore files in the build cache.")
    g.add_argument("--build-only",
                   action="store_true",
                   help="Do not launch fuzzer, but only do the build.")
    g.add_argument(
        "--solc-version",
        default="auto",
        help=
        "select solidity version. default is to auto-detect based on pragma.")
    g.add_argument(
        '--translate-all',
        action='store_true',
        help=
        'Translate all contracts found in a solidity source file or combined.json build.'
        ' (Useful when e.g., the contract creates other contract in the constructor)'
    )

    # ========================================================================
    parser.add_argument(
        "-o",
        "--out",
        type=Path,
        default=Path("./efcf_out/"),
        help="path to a directory or tar.xz, which stores the fuzzing results")

    parser.add_argument(
        "--remove-out-on-failure",
        choices=('y', 'n'),
        default='n',
        # type=bool_choice,
        help="remove out file on failure.")

    parser.add_argument("-v",
                        "--verbose",
                        action="store_true",
                        help="enable verbose logging")
    parser.add_argument("-B",
                        "--verbose-build",
                        action="store_true",
                        help="enable verbose logging of the build process")
    parser.add_argument(
        "-q",
        "--quiet",
        action="store_true",
        help="suppress fuzzer output *and* disable verbose logging")

    args = parser.parse_args()
    args.install_dir = realpath(args.install_dir)
    args.build_cache = realpath(args.build_cache)
    args.eevm_path = realpath(args.eevm_path)
    args.fuzz_dir = realpath(args.fuzz_dir)

    args.cleanup_kills = (args.cleanup_kills.lower() == 'y')
    args.compress_builds = (args.compress_builds.lower() == 'y')
    args.remove_out_on_failure = (args.remove_out_on_failure.lower() == 'y')
    args.include_address_deps = (args.include_address_deps.lower() == 'y')
    args.ignore_initial_ether = (args.ignore_initial_ether == 'y')
    args.include_mapping_deps = (args.include_mapping_deps == 'y')
    args.multi_target = (args.multi_target == 'y')
    args.compute_evm_cov = (args.compute_evm_cov == 'y')
    args.generate_cov_plots = (args.generate_cov_plots == 'y')

    args.multi_target_addresses = []

    if args.assertions:
        args.event_assertions = True
        args.sol_assertions = True

    return args


def find_cached_build(config, target, buildtype, hashed=None):
    lname = DEFAULT_BUILD_FORMAT.format(name=target,
                                        btype=buildtype,
                                        hashed=("." +
                                                hashed if hashed else ""))

    if config.compress_builds:
        lname += '.tar.xz'
    cachedpath = realpath(config.build_cache) / lname
    exists = False if config.ignore_cached_builds else cachedpath.exists()

    return exists, cachedpath


def launch():
    args = parse_args()
    log("launching EF/CF")

    if args.verbose and not args.quiet:
        set_log_level(logging.DEBUG)
        log("enabled verbose logging", level=logging.DEBUG)

    if not check_and_extend_path(args):
        exit_with(EXIT_INVALID_PARAMS,
                  "cannot find all necessary dependencies!")

    if args.version:
        version = ""
        if args.install_dir.exists():
            with pushdir(args.install_dir):
                if is_git_dir("."):
                    version = sp.check_output(
                        "git log -n 1 --pretty='format:%H %aI'", shell=True)
                    version = version.decode('utf-8').strip()
                elif (args.install_dir / "version").exists():
                    with (args.install_dir / "version").open() as f:
                        version = log(f.read())
        else:
            logw("failed to determine installation dir")
        log("version information:", version.strip())

        run("evm2cpp --version", p=1)
        run("efuzzcaseanalyzer --version", p=1)
        # run("afl-fuzz --version", p=1)
        log(f"""install paths:
    EFCF_INSTALL_DIR={args.install_dir!s} (--install-dir)
    EFCF_BUILD_CACHE={args.build_cache!s} (--build-cache)
    EFCF_FUZZ_DIR={args.fuzz_dir!s} (--fuzz-dir)
    EVM_PATH={args.eevm_path!s} (--eevm-patch)
""")
        sys.exit(EXIT_SUCCESS)

    if args.configure_system:
        logw(
            "configuring system for high-performance fuzzing (requires root)!")
        sudo("afl-system-config", p=1)
        log("configuration done - temporary config until reboot")

    if args.live_state:

        if len(args.live_state) == 1 and os.path.exists(args.live_state[0]):
            with open(args.live_state[0]) as f:
                addresses = list(map(str.strip, f.readlines()))
        else:
            addresses = []

            for addrs in args.live_state:
                if "," in addrs:
                    addrs = addrs.split(",")
                else:
                    addrs = [addrs]

                for a in addrs:
                    addresses.append(a.strip())

        if not addresses:
            exit_with(
                EXIT_INVALID_PARAMS,
                "need to provide at least one address for live-state fuzzing!")

        for a in addresses:
            if not a.startswith("0x"):
                exit_with(EXIT_INVALID_PARAMS,
                          f"invalid address provided: {a!r}")

            if isinstance(a, int):
                ai = a
            else:
                ai = int(a, 0)
            if not looks_like_address(ai):
                logw(
                    "provided address", a,
                    "that does not look like an address? are you sure about this?"
                )

        addresses = list(map(normalize_ethereum_address, addresses))
        target = addresses[0]

        if args.live_state_target:
            target = args.live_state_target.strip()

        if not target.startswith("0x"):
            exit_with(EXIT_INVALID_PARAMS,
                      f"invalid address provided: {target!r}")

        target = normalize_ethereum_address(target)

        if args.seed_from_ethbmc_attacks:
            attack_seeds = Path(args.fuzz_dir) / "ethbmc_attack_seeds" / target
            attack_seeds.mkdir(parents=True, exist_ok=True)
            log(
                "seeding fuzzer from EthBMC results for testing - extracting from",
                args.seed_from_ethbmc_attacks, "to", attack_seeds)
            if not make_seeds_from_ethbmc_zip(attack_seeds, target,
                                              args.seed_from_ethbmc_attacks):
                exit_with(EXIT_BUILD_FAILURE,
                          "failed to create seeds from ethbmc")
            args.seed_files = attack_seeds

        if args.name:
            t = args.name.strip()
        else:
            t = target

        blocknum = 0
        if args.live_state_blocknumber:
            blocknum = args.live_state_blocknumber
        else:
            geth_init(args)
            blocknum = get_geth_blocknumber()

        hkey = t.encode('utf-8')
        h = hashlib.blake2b(hkey, digest_size=16)
        for a in addresses:
            h.update(str(a).encode('utf-8'))
        for v in (args.include_address_deps, args.include_mapping_deps,
                  args.geth_preset, blocknum, args.multi_target):
            h.update(str(v).encode('utf-8'))
        hashed = h.hexdigest()

        buildtype = f"state_b{blocknum}"
        exists, build = find_cached_build(args, t, buildtype, hashed=hashed)

        if not exists:
            geth_init(args)

            r = create_state_build(args, target, addresses, build,
                                   args.eevm_path)
            if not r:
                exit_with(EXIT_BUILD_FAILURE, "build failure - stopping now")
        else:
            log("using cached build", build)

        if args.multi_target:
            args.multi_target_addresses = addresses
            log(
                "Enabling multi-target mode with the following target contracts:",
                " ".join(addresses))

    elif args.source:

        for srcpath in args.source:
            if srcpath.suffix != ".sol":
                logw(
                    f"Are you sure {srcpath!s} is a valid solidity source file?"
                )

        hkey = args.name.encode('utf-8') if args.name else b""
        hkey += args.solc_version.encode("utf-8")
        hkey += str(int(args.translate_all)).encode("utf-8")
        h = hashlib.blake2b(hkey, digest_size=16)

        for file in sorted(set(args.source)):
            with file.open("rb") as f:
                h.update(f.read())
        hashed = h.hexdigest()

        buildcache = get_build_cache(args)

        combinedout = buildcache / (hashed + "_build.combined.json")
        name_out = buildcache / (hashed + ".name")

        if combinedout.exists() and name_out.exists():
            with open(name_out) as f:
                name = f.read().strip()
        else:
            name = compile_source(args, args.source, combinedout)

            if name is None:
                exit_with(
                    EXIT_BUILD_FAILURE,
                    "failed to obtain contract name from sources: {args.source!s}"
                )

            with open(name_out, "w") as f:
                print(name, file=f)

        exists, build = find_cached_build(args, name, "src", hashed)

        if not exists:
            args.bin_runtime = combinedout
            r = create_runtime_build(args, name, build, args.eevm_path)
            if not r:
                exit_with(EXIT_BUILD_FAILURE, "build failure - stopping now")
        else:
            log("using cached build", build)
    elif args.bin_runtime:
        if args.name:
            name = args.name
        else:
            name = str(args.bin_runtime.name)
            name = name.split(".")[0]

        hkey = args.name.encode('utf-8') if args.name else b""
        h = hashlib.blake2b(hkey, digest_size=16)

        buildfiles = [args.bin_runtime]

        if args.bin_deploy:
            buildfiles.append(args.bin_deploy)

        if args.abi:
            buildfiles.append(args.abi)

        for file in buildfiles:
            with file.open("rb") as f:
                h.update(f.read())
        hashed = h.hexdigest()

        exists, build = find_cached_build(args, name, "bin", hashed)

        if not exists:
            r = create_runtime_build(args, name, build, args.eevm_path)
            if not r:
                exit_with(EXIT_BUILD_FAILURE, "build failure - stopping now")
        else:
            log("using cached build", build)
    elif args.force_use_build:
        build = args.force_use_build

    else:
        exit_with(EXIT_INVALID_PARAMS,
                  "wut? no action (--source, --bin-runtime,...) provided?")

    if not build.exists():
        exit_with(EXIT_BUILD_FAILURE, "build failure - stopping now")

    if not args.build_only:
        os.makedirs(args.fuzz_dir, exist_ok=True)
        res, _, _ = launch_fuzzer(build, args, realpath(args.out),
                                  realpath(args.fuzz_dir))
        log(f"fuzzer stopped - results stored to {args.out}")
        if not res:
            exit_with(EXIT_FUZZ_FAILURE, "fuzzer failed")

    sys.exit(EXIT_SUCCESS)
