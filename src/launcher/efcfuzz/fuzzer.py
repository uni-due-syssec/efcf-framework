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

import datetime
import glob
import logging
import os
import select
import shutil
import subprocess as sp
import sys
import tarfile
import tempfile
from multiprocessing import cpu_count
from pathlib import Path
from time import sleep

from .builder import (DEFAULT_MULTI_ABILIST, DEFAULT_MULTI_ADDRLIST,
                      DEFAULT_STATE_DICT, DEFAULT_STATE_FILE,
                      DEFAULT_TARGET_NAME, extract_build)
from .utils import (log, loge, logw, normalize_ethereum_address, pushdir,
                    realpath, run, set_or_remove)


class AFLStats:
    __slots__ = ('time', 'total_time', 'total_eps', 'total_execs',
                 'total_crashes', 'total_hangs', 'avg_eps', 'fuzzers',
                 'avg_corpus_count', 'avg_corpus_found', 'avg_bitmap_cov')

    def __init__(self, target_dir="."):
        with pushdir(target_dir):
            #     # based on the summary mode of afl-whatsup by Michael Zalewski \
            #     # (see https://github.com/AFLplusplus/AFLplusplus/blob/stable/afl-whatsup)
            self.total_time = 0
            self.total_eps = 0
            self.total_execs = 0
            self.total_crashes = 0
            self.total_hangs = 0
            self.avg_eps = 0
            self.avg_corpus_count = 0
            self.avg_corpus_found = 0
            self.avg_bitmap_cov = 0

            run_unix = 0
            fuzzers = 0
            corpus_count = 0
            corpus_found = 0
            bitmap_cov = 0.0

            for fuzzer_stat_path in glob.glob("./*/fuzzer_stats"):
                fuzzers += 1

                fuzzer_stats_str = ""
                with open(fuzzer_stat_path) as f:
                    fuzzer_stats_str = f.read()

                fuzzer_stats = {}

                for line in fuzzer_stats_str.splitlines(keepends=False):
                    x = iter(map(lambda x: x.strip(), line.split(":")))
                    k = next(x)
                    v = next(x)
                    try:
                        v = float(v)
                    except ValueError:
                        try:
                            v = int(v, 0)
                        except ValueError:
                            pass
                    fuzzer_stats[k] = v

                run_unix = fuzzer_stats.get("run_time", 0)
                execs_done = fuzzer_stats.get("execs_done", 0)
                exec_sec = 0

                if run_unix != 0:
                    exec_sec = execs_done / run_unix

                corpus_count += fuzzer_stats.get("corpus_count", 0)
                corpus_found += fuzzer_stats.get("corpus_found", 0)
                bitmap_cov += float(
                    fuzzer_stats.get("bitmap_cvg",
                                     "0.0%").strip().strip("%").strip())

                self.total_time += run_unix
                self.total_eps += exec_sec
                self.total_execs += execs_done
                self.total_crashes += int(fuzzer_stats.get("saved_crashes", 0))
                self.total_hangs += int(fuzzer_stats.get("saved_hangs", 0))

            if fuzzers != 0:
                self.avg_eps = self.total_eps / fuzzers
                self.avg_corpus_count = corpus_count / fuzzers
                self.avg_corpus_found = corpus_found / fuzzers
                self.avg_bitmap_cov = bitmap_cov / fuzzers

            self.time = run_unix
            self.fuzzers = int(fuzzers)

    def __str__(self):
        return f"""time                     : {self.time}
total_time               : {self.total_time}
total_execs_done         : {self.total_execs}
cumulative_execs_per_sec : {self.total_eps}
average_execs_per_sec    : {self.avg_eps}
total_crashes            : {self.total_crashes}
total_hangs              : {self.total_hangs}
fuzzer_count             : {self.fuzzers}
average_corpus_count     : {self.avg_corpus_count}
average_corpus_found     : {self.avg_corpus_found}
average_bitmap_cvg       : {self.avg_bitmap_cov}
"""


def kill_remaining():
    log("killing potential remaining target/fuzzer processes",
        level=logging.DEBUG)
    run("pkill -KILL fuzz_multitx", shell=True)
    run("pkill -KILL afl-fuzz", shell=True)


def launch_fuzzer(build,
                  config,
                  outpath: Path,
                  fuzz_dir: Path,
                  run_prefix=None,
                  postfix=""):
    afl_exitcode = -1
    aflstats = None
    if run_prefix is None:
        run_prefix_base = os.path.basename(build)
        if run_prefix_base.endswith(".fuzz.build"):
            run_prefix_base = run_prefix_base[:-11]
        if run_prefix_base.endswith(".tar.xz"):
            run_prefix_base = run_prefix_base[:-7]
        run_prefix = "./" + run_prefix_base
    else:
        run_prefix_base = os.path.basename(run_prefix)
    with tempfile.TemporaryDirectory(dir=fuzz_dir,
                                     prefix=run_prefix_base + ".",
                                     suffix=".fuzz") as fuzz_cwd:

        log(f"extracting build files to {fuzz_cwd}")
        with pushdir(fuzz_cwd):
            if not extract_build(Path(build)):
                return (False, -1, None)

            for path in ("./target_name", "./fuzz", "./fuzz/build/afuzz",
                         "fuzz/launch-aflfuzz.sh"):
                if not os.path.exists(path):
                    log(f"no {path} in build {build}", level=logging.ERROR)
                    return (False, -1, None)

            target = ""
            target_path = Path(DEFAULT_TARGET_NAME)
            if target_path.exists():
                with target_path.open() as f:
                    target = f.read().strip()
            else:
                if config.name:
                    target = config.name
                else:
                    target = run_prefix_base

            if not target:
                log(f"invalid target {target!r}", level=logging.ERROR)
                return (False, -1, None)

            # check if the build is a multi-target build
            multi_target_path = Path(DEFAULT_MULTI_ADDRLIST)
            if (multi_target_path.exists()
                    and not config.multi_target_addresses):
                with multi_target_path.open() as f:
                    config.multi_target_addresses = [
                        normalize_ethereum_address(a)
                        for a in f.read().strip().split(",")
                    ]
                    config.multi_target = True
                    log("overriding multi-target setting for given build",
                        "target =", target, " addresses =",
                        ",".join(config.multi_target_addresses))

            log("preparing fuzz for target", target)

            time = config.timeout
            time_td = datetime.timedelta(seconds=time)
            mode = config.fuzzmode
            env = os.environ.copy()

            env["FUZZ_CLEANUP_KILLS"] = int(bool(config.cleanup_kills))

            env = set_or_remove(env, 'AFL_BENCH_UNTIL_CRASH',
                                config.until_crash)

            # configure detectors / bug oracles
            env['EVM_DISABLE_DETECTOR'] = int(bool(config.disable_detectors))
            env['EVM_IGNORE_LEAKING'] = int(not (
                bool(config.report_leaking_ether)))
            env['EVM_REPORT_DOS_SELFDESTRUCT'] = int(
                bool(config.report_dos_selfdestruct))
            env['EVM_REPORT_SOL_PANIC'] = int(bool(config.sol_assertions))
            env['EVM_REPORT_EVENTS'] = int(bool(config.event_assertions))
            env['EVM_REPORT_EVENTS_ONLY_TARGET'] = int(
                bool(config.event_assertions_target_only))
            env = set_or_remove(env, 'EVM_LOG_TOPICS_PATH',
                                config.event_assertions_list)

            # make sure there are some environment variables that are never set during fuzzing runs
            env.pop("EVM_DEBUG_PRINT", None)
            env.pop("EVM_CMP_LOG", None)
            env.pop("EVM_COVERAGE_FILE", None)

            env = set_or_remove(env, 'EVM_PROPERTY_PATH', config.properties)

            cores = 1
            if config.cores:
                cores = min(config.cores, cpu_count())
                env['FUZZ_CORES'] = str(cores)
                log(f"launcher fuzzer on {cores} CPU cores")

            if mode == "monly":
                env["FUZZ_CMPLOG_ARG"] = "none"
                env["AFL_CUSTOM_MUTATOR_ONLY"] = "1"
            else:
                if "AFL_CUSTOM_MUTATOR_ONLY" in env:
                    del env["AFL_CUSTOM_MUTATOR_ONLY"]

                if mode == "none":
                    env["FUZZ_CMPLOG_ARG"] = "none"
                else:
                    env["FUZZ_CMPLOG_ARG"] = f"-l {mode}"

            if config.exec_timeout:
                env['FUZZ_EXEC_TIMEOUT'] = f"-t {config.exec_timeout}"
            else:
                env.pop('FUZZ_EXEC_TIMEOUT', None)

            env["FUZZ_USE_SHM"] = "0"
            env["FUZZ_USE_TMPFS"] = "0"

            if config.seed_files:
                env['FUZZ_SEEDS_DIR'] = realpath(config.seed_files)

            if os.path.exists(DEFAULT_STATE_FILE):
                log(f"using state file {DEFAULT_STATE_FILE}")
                env['EVM_LOAD_STATE'] = str(DEFAULT_STATE_FILE)
                env['EVM_TARGET_ADDRESS'] = str(target)
                if os.path.exists(DEFAULT_STATE_DICT):
                    env['DICT_PATH'] = str(DEFAULT_STATE_DICT)

                env.pop("EVM_CREATE_TX_INPUT", None)
                env.pop("EVM_CREATE_TX_ARGS", None)
            elif config.create_tx_input:
                env = set_or_remove(env, 'EVM_CREATE_TX_INPUT',
                                    config.create_tx_input)
                env.pop('EVM_CREATE_TX_ARGS', None)
            elif config.deploy_args and config.deploy_args.exists():
                env = set_or_remove(env, 'EVM_CREATE_TX_ARGS',
                                    config.deploy_args)
                env.pop('EVM_CREATE_TX_INPUT', None)

            if config.multi_target and config.multi_target_addresses:
                a = ','.join(config.multi_target_addresses)
                env["EVM_TARGET_MULTIPLE_ADDRESSES"] = a
            else:
                env.pop("EVM_TARGET_MULTIPLE_ADDRESSES", None)

            env['FUZZ_LAUNCHER_DONT_REBUILD'] = "1"
            env['FUZZ_NO_SUDO'] = "1"

            env['FUZZ_EVMCOV'] = ("1" if config.compute_evm_cov else "0")
            env['FUZZ_PLOT'] = ("1" if config.generate_cov_plots else "0")

            env['EVM_NO_INITIAL_ETHER'] = ("1" if config.ignore_initial_ether
                                           else "0")

            env = set_or_remove(env, 'EVM_MOCK_ALL_CALLS',
                                config.over_approximate_all_calls)

            if os.path.exists(config.install_dir):
                env['EFCF_INSTALL_DIR'] = config.install_dir

            if os.path.exists(config.eevm_path):
                p = os.path.join(config.eevm_path, "fuzz", "launch-aflfuzz.sh")
                if os.path.exists(p):
                    shutil.copy(p, "./fuzz/launch-aflfuzz.sh")

            # make sure we can execute those...
            run("chmod +x ./fuzz/*.sh", shell=True)
            run("chmod +x ./fuzz/build/*/*/fuzz_*", shell=True)

            # make sure everything is a string!
            env = {k: str(v) for k, v in env.items()}

            timelog = realpath(run_prefix + ".fuzz.time")
            fuzzlog = realpath(run_prefix + ".fuzz.log")

            def find_fuzz_out():
                fuzz_out_dir = Path("./fuzz/out/")
                if fuzz_out_dir.exists() and fuzz_out_dir.is_dir():
                    log("fuzz/out dir exists as expected", level=logging.DEBUG)
                else:
                    loge("fuzzer did not produce expected output!")
                    return None

                fuzz_out = None
                for out in fuzz_out_dir.iterdir():
                    if target in out.name:
                        fuzz_out = out

                if not (fuzz_out.exists() and
                        (fuzz_out.is_dir() or fuzz_out.is_symlink())):
                    loge(
                        f"fuzz output directory '{fuzz_out!s}' does not exist in",
                        str(list(fuzz_out_dir.iterdir())))
                    return None

                return fuzz_out.resolve()

            pprogress_times = []
            if config.print_progress and time > 30:
                if time <= (60 * 10):
                    parts = 5
                elif time <= (4 * 60 * 60):
                    parts = 10
                else:
                    parts = 100
                # first one is 0 now, but we'll overwrite this one later
                pprogress_times = list(range(0, time, time // parts))
                # about 32 seconds in print first progress
                x = 32
                if cores > 4:
                    # except if we launch a lot of fuzzers; then wait for all
                    # fuzzers to be launched and hopefully, some of them
                    # already wrote something to the stats file
                    x += (cores * 2)
                if pprogress_times[1] > x:
                    pprogress_times[0] = x
                else:
                    pprogress_times[0] = pprogress_times[1] // 2
                # add 2 minutes after timeout s.t., we have a sane default at
                # the end?
                pprogress_times.append(time + 120)

            log("launching fuzzer now! (AFL++ afl-fuzz)")
            try:
                afl = []
                timebin = shutil.which("time")
                if timebin:
                    afl = ["/usr/bin/time", "-v", "-o", timelog]

                afl += ["./fuzz/launch-aflfuzz.sh", target, str(time)]
                if postfix:
                    afl.append(postfix)
                log("launching command:", afl, level=logging.DEBUG)
                with open(fuzzlog, "wb") as logf:
                    start_time = datetime.datetime.now()
                    proc = sp.Popen(afl,
                                    stdout=sp.PIPE,
                                    stderr=sp.PIPE,
                                    env=env)

                    sleep(1)
                    fuzz_out = find_fuzz_out()
                    if config.print_progress and not fuzz_out:
                        logw(
                            "could not locate fuzzer output dir for progress logging!"
                        )
                        config.print_progress = False

                    fno_out = proc.stdout.fileno()
                    fno_err = proc.stderr.fileno()
                    try:
                        while proc.poll() is None:
                            r, _w, _e = select.select([fno_out, fno_err], [],
                                                      [], 10)
                            for fileno in (fno_err, fno_out):
                                if fileno in r:
                                    buf = os.read(fileno, 1024)
                                    logf.write(buf)
                                    if not config.quiet:
                                        sys.stdout.buffer.write(buf)
                                        sys.stdout.flush()

                            if config.print_progress and fuzz_out and pprogress_times:
                                now = datetime.datetime.now()
                                timepassed = (now - start_time).total_seconds()
                                if timepassed > pprogress_times[0]:
                                    pprogress_times.pop(0)
                                    aflstats = AFLStats(fuzz_out)
                                    log(f"Current Fuzzing Progress ({now - start_time} of {time_td}):\n{aflstats}"
                                        )

                    except KeyboardInterrupt:
                        log("received stop signal - terminating fuzzer")
                        proc.terminate()
                        sleep(1)

                    try:
                        while proc.poll() is None:
                            r, _w, _e = select.select([fno_out, fno_err], [],
                                                      [], 10)
                            for fileno in (fno_err, fno_out):
                                if fileno in r:
                                    buf = os.read(fileno, 1024)
                                    logf.write(buf)
                                    if not config.quiet:
                                        sys.stdout.buffer.write(buf)
                                        sys.stdout.flush()
                    except KeyboardInterrupt:
                        logw("received stop signal again - killing fuzzer")
                        proc.kill()
                        sleep(1)

                afl_exitcode = proc.poll()

                log(f"afl-fuzz is done (exit code => {afl_exitcode})")

                log("compressing fuzz log", level=logging.DEBUG)
                run("xz", fuzzlog)

                log('saving some fuzzing related artifacts',
                    level=logging.DEBUG)

                fuzz_out = find_fuzz_out()
                if not fuzz_out:
                    return (False, -1, None)

                try:
                    df_out = sp.check_output([
                        "df", "-h",
                        str(fuzz_out.parent.absolute()),
                        str(outpath.parent.absolute())
                    ])
                    log("filesystem size check:\n" +
                        df_out.decode(errors='replace'),
                        level=logging.DEBUG)
                except sp.CalledProcessError:
                    log("failed to execute `df -h ...`",
                        level=logging.DEBUG,
                        exc_info=True)

                # we copy everything in the contracts directory since
                # this should make analysis easier!
                if os.path.exists("./contracts"):
                    shutil.copytree("./contracts",
                                    os.path.join(fuzz_out, "contracts"))
                else:
                    logw("cannot find ./contracts in ",
                         str(list(os.listdir("."))))

                if os.path.exists("./fuzz/abi"):
                    shutil.copytree("./fuzz/abi",
                                    os.path.join(fuzz_out, "contracts/abi"))
                else:
                    logw("cannot find ./fuzz/abi in ",
                         str(list(os.listdir("."))))

                # we definitly want to copy the binary for easy crash
                # reproducing.
                binpath = os.path.join(fuzz_out, "build", "fuzz_multitx")
                if os.path.exists(binpath):
                    shutil.copy(binpath, fuzz_out)
                else:
                    logw(f"cannot find {binpath!s} in ",
                         str(list(os.listdir(fuzz_out))))

                # log("fuzz_out:", list(map(str, fuzz_out.iterdir())), level=logging.DEBUG)

                fuzzlog_xz = fuzzlog.parent / (fuzzlog.name + ".xz")
                if fuzzlog_xz.exists():
                    shutil.copy(fuzzlog_xz, fuzz_out)
                elif fuzzlog.exists():
                    logw("copying uncompressed fuzzing log!")
                    shutil.copy(fuzzlog, fuzz_out)
                else:
                    logw("Could not locate fuzzing log!")

                if timelog.exists():
                    shutil.copy(timelog, fuzz_out)

                with open("/proc/cpuinfo") as f:
                    cpuinfo = f.read()
                with (fuzz_out / "fuzz.cpu").open("w") as f:
                    f.write(cpuinfo)

                def path_or_none(x):
                    return Path(x) if x is not None else None

                to_check = (DEFAULT_STATE_FILE, DEFAULT_STATE_DICT,
                            config.deploy_args, config.create_tx_input)
                for fpath in map(path_or_none, to_check):
                    if fpath and fpath.exists():
                        log(f"copy of {fpath!s}", level=logging.DEBUG)
                        shutil.copy(fpath, fuzz_out)

                log("sanitizing fuzz-config.sh", level=logging.DEBUG)
                with pushdir(fuzz_out):
                    fuzz_config_path = Path("./fuzz-config.sh")
                    if not fuzz_config_path.exists():
                        loge(
                            "could not find / sanitize fuzz-config.sh - what up?"
                        )
                    else:
                        fuzz_config_as_dict = {}
                        # first read the fuzz-config.sh
                        with fuzz_config_path.open() as f:
                            fuzz_config = f.readlines()
                        # we parse every line
                        for line in fuzz_config:
                            line = line.strip()
                            split_at = line.index("=")
                            key = line[:split_at]
                            value = line[(split_at + 1):].strip()
                            if value[0] in ('"', "'"):
                                value = value[1:-1]
                            fuzz_config_as_dict[key] = value

                            # now we do a little sanitization. if the
                            # value is a path and in the cwd is also
                            # a file with the respective name, then we
                            # set the path to a relative one.
                            if not value:
                                continue
                            p = Path(value)
                            if p.is_relative_to("."):
                                continue
                            if Path(p.name).exists():
                                fuzz_config_as_dict[key] = p.name

                        # write sanitized fuzz-config.sh
                        with fuzz_config_path.open("w") as fw:
                            for k, v in fuzz_config_as_dict.items():
                                fw.write(f"{k!s}={v!s}\n")

                aflstats = AFLStats(fuzz_out)
                log("checking fuzzing results\n" + str(aflstats))

                if shutil.which("efuzzcasesynthesizer"):
                    log("synthesizing solidity attack", level=logging.DEBUG)
                    with pushdir(fuzz_out):
                        attackspath = Path(fuzz_out) / "attacks"
                        if not attackspath.exists():
                            attackspath.mkdir(parents=True, exist_ok=True)

                        for crashs in glob.glob("./crashes_min/*"):
                            crash = Path(crashs)
                            out = attackspath / (crash.name + ".sol")
                            cmd = ["efuzzcasesynthesizer"]
                            abipath = Path(fuzz_out) / "contract.abi"
                            if abipath.exists():
                                cmd += ["-a", str(abipath)]
                            cmd += [str(crash), str(out)]
                            run(*cmd)

                if afl_exitcode != 0:
                    logw("AFL++ fuzzer seems to have failed!")

                bugs = None
                bugpath = os.path.join(fuzz_out, "bugs")
                if os.path.exists(bugpath):
                    with open(bugpath) as f:
                        bugs = f.read()
                        if bugs:
                            logw("Identified bugs:\n" + str(bugs) + "\n")
                if not bugs:
                    log("No bugs identified")

                covpath = fuzz_out / "coverage-percent-all.evmcov"
                if covpath.exists():
                    with covpath.open() as f:
                        try:
                            cov = float(f.read().strip())
                            log(f"Code Coverage (Basic Blocks) => {cov:.2f} %")
                        except ValueError:
                            pass

                if outpath.exists():
                    logw("over-writing existing fuzzing run!")
                    if outpath.is_dir():
                        shutil.rmtree(outpath)
                    else:
                        outpath.unlink()

                # outpath is removed and we do not create a new one.
                if afl_exitcode != 0 and config.remove_out_on_failure:
                    return (False, afl_exitcode, aflstats)

                if str(outpath).endswith(".tar.xz"):
                    log("compressing to", outpath)
                    EXCLUDE_FILES = [
                        "./build", '.git', '.cache', '.ccache', 'core'
                    ]

                    def filterfunc(x):
                        if x.name in EXCLUDE_FILES:
                            return None
                        p = Path(x.name)
                        if p.name in EXCLUDE_FILES:
                            return None
                        if str(x.name).startswith("core."):
                            return None
                        return x

                    with pushdir(fuzz_out):
                        outpath = Path(outpath)
                        if not outpath.parent.exists():
                            outpath.parent.mkdir(parents=True, exist_ok=True)
                        # with tarfile.open(str(outpath),
                        #                   'w:xz',
                        #                   dereference=True) as tf:
                        #     tf.add(".", filter=filterfunc)

                        cores = 1
                        if config.cores:
                            cores = int(config.cores)
                        # shell out to tar to use parallel xz
                        run("tar", "--dereference", "-I", f"xz -T {cores}",
                            "-cf", str(outpath), ".")

                else:
                    shutil.copytree(fuzz_out, outpath, dirs_exist_ok=True)
            finally:
                if config.cleanup_kills:
                    kill_remaining()
    log("fuzzer is done", level=logging.DEBUG)
    return (afl_exitcode == 0, afl_exitcode, aflstats)
