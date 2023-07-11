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

import contextlib
import logging
import os
import pathlib
import shutil
import subprocess
import sys
from pathlib import Path

NEED_SUDO = os.geteuid() != 0 and os.getuid() != 0

FORMAT = '%(asctime)s %(hostname)s %(levelname)s %(message)s [%(process)d %(cwd)s]'
logger = None

try:
    logger = logging.getLogger("efcf")
    import coloredlogs
    coloredlogs.install(level='INFO', logger=logger, fmt=FORMAT)
except ImportError:
    coloredlogs = None
    logging.basicConfig(level=logging.INFO, format=FORMAT)
    logger = logging.getLogger("efcf")

_old_logrec_factory = logging.getLogRecordFactory()


def _log_record_factory(*args, **kwargs):
    record = _old_logrec_factory(*args, **kwargs)
    record.cwd = os.getcwd()

    return record


logging.setLogRecordFactory(_log_record_factory)


def set_log_level(level):
    global logger, coloredlogs
    assert logger
    if coloredlogs:
        coloredlogs.install(level=level, logger=logger, fmt=FORMAT)
    logger.setLevel(level)


def log(msg, *args, level=logging.INFO, sep=' ', **kwargs):
    if args:
        msg += sep + sep.join(map(str, args))
    return logger.log(level, msg, **kwargs)


def logw(msg, *args, level=logging.WARNING, sep=' ', **kwargs):
    log(msg, *args, level=level, sep=sep, **kwargs)


def loge(msg, *args, level=logging.ERROR, sep=' ', **kwargs):
    log(msg, *args, level=level, sep=sep, **kwargs)


def exit_with(code, msg, *args, level=logging.CRITICAL, sep=' ', **kwargs):
    if msg:
        log(msg, *args, level=level, sep=sep, **kwargs)
    sys.exit(int(code))


def realpath(path):
    # return os.path.realpath(os.path.expanduser(path))
    path = pathlib.Path(path)
    return path.expanduser().absolute()


def existing_path(s):
    """
    useful for argparse type=
    """
    if s is None:
        return None
    p = Path(s)

    if not p.exists():
        raise ValueError("Non-existing path provided")

    return p.absolute().expanduser()


def run(*args, p=False, **kwargs):
    try:
        args = list(map(str, args))

        if len(args) == 1:
            if "shell" not in kwargs:
                kwargs["shell"] = True

        if p:
            log(f"command: {' '.join(args)}")
        else:
            log(f"command: {' '.join(args)}", level=logging.DEBUG)

        return subprocess.run(args, **kwargs)
    except subprocess.CalledProcessError as e:
        x = " ".join(args)
        log(f"cmd '{x}' failed with {e.returncode}", logging.WARNING)

        return None


def normalize_ethereum_address(a):
    if not isinstance(a, int):
        a = int(a, 0)
    return f"{a:#042x}"


def looks_like_address(address: int):
    """
    Ethereum addresses are 20-byte long and look quite random. In this function
    we try to filter out values that exhibit obviously low entropy, look like
    bitmasks or small integers.
    """
    bitlen = address.bit_length()
    if 152 <= bitlen and bitlen <= 160:
        # first make sure there is something in the lower bits
        if address & 0xffffffffffffffffffff == 0:
            return False

        # then count the null bytes and 0xff bytes
        nulls = 0
        ffs = 0
        for i in range(20):
            bval = (address >> (8 * i)) & 0xff
            if bval == 0:
                nulls += 1
            elif bval == 0xff:
                ffs += 1
        if nulls <= 3 and ffs <= 3 and (nulls + ffs) <= 4:
            return True

    return False


def sudo(*args, **kwargs):
    if NEED_SUDO:
        args = list(args)
        args.insert(0, "sudo")

    return run(*args, **kwargs)


@contextlib.contextmanager
def pushdir(path):
    prev_cwd = os.getcwd()
    os.chdir(path)
    try:
        yield
    finally:
        os.chdir(prev_cwd)


def is_git_dir(wd="."):
    r = run("git rev-parse --git-dir", shell=True, stdout=subprocess.DEVNULL)

    if r is not None:
        return r.returncode == 0

    return False


def exist_all(*paths):
    return all(map(lambda x: os.path.exists(x), paths))


def set_or_remove(d, k, v):
    if v:
        d[k] = str(v)
    else:
        d.pop(k, None)
    return d


def is_on_tmpfs(path: Path):
    avoid_mnts = list(map(Path, ('/', '/dev/', '/proc/', '/sys')))
    mtabp = Path("/etc/mtab")
    # sometimes mtab doesn't exist, seems to be there for compat only
    if not mtabp.exists():
        mtabp = Path("/proc/self/mounts")
        if not mtabp.exists():  # odd, but ok.
            mtabp = None
    if mtabp is not None:
        with mtabp.open() as f:
            mtab = map(str.strip, f.readlines())
            for line in mtab:
                line = line.split(" ")
                dev = line[0].strip()
                mntpoint = Path(line[1].strip())
                if not mntpoint.exists():
                    continue
                if not mntpoint.name:
                    continue
                if mntpoint in avoid_mnts:
                    continue
                opts = list(map(str.strip, line[3].strip().split(",")))
                # we need a executable tmpfs since we unpack build artifacts
                if "noexec" in opts:
                    continue

                if path.is_relative_to(mntpoint):
                    if dev == "tmpfs" or "zram" in dev:
                        return True, mntpoint
                    return False, mntpoint
    return False, None


def find_fuzz_dir_candidate():
    candidates = ('/tmp/efcf/', '/dev/shm/efcf/', '/var/tmp/efcf')
    for p in map(Path, candidates):
        t, mnt = is_on_tmpfs(p)
        if t:
            log(f"using fuzz dir on {p!s}", level=logging.DEBUG)
            return p.absolute()
    return Path(candidates[0])


def check_and_extend_path(config):
    log("checking for dependencies", level=logging.DEBUG)

    config.install_dir = Path(config.install_dir)
    config.eevm_path = Path(config.eevm_path)
    config.build_cache = Path(config.build_cache)

    if not shutil.which("afl-fuzz"):
        afl_dir = config.install_dir / "src" / "AFLplusplus"

        if not exist_all(config.install_dir, afl_dir):
            loge("failed to locate AFL++ dir at", afl_dir)

            return False

        if not (afl_dir / "afl-fuzz").exists():
            with pushdir(afl_dir):
                log("building AFL++")
                run("make source-only NO_SPLICING=1 NO_PYTHON=1 NO_NYX=1", p=1)

        os.environ['PATH'] += f":{afl_dir!s}"

        if not shutil.which("afl-fuzz"):
            loge("failed to locate AFL++ afl-fuzz")
            return False

    if not shutil.which("evm2cpp"):
        idir = config.install_dir / "src" / "evm2cpp"

        if not exist_all(config.install_dir, idir):
            loge("failed to locate evm2cpp dir at", idir)
            return False

        bdir = idir / "target" / "release"

        if not (bdir / "evm2cpp").exists():
            with pushdir(idir):
                log("building evm2cpp")
                run("cargo build --release", shell=True, p=1)

        os.environ['PATH'] += f":{bdir!s}"

        if not shutil.which("evm2cpp"):
            loge("failed to locate/build evm2cpp")

            return False

    if not shutil.which("efuzzcaseanalyzer"):
        idir = config.install_dir / "src" / "ethmutator"
        if not exist_all(config.install_dir, idir):
            loge("failed to locate ethmutator dir at", idir)
            return False

        bdir = idir / "target" / "release"

        if not (bdir / "efuzzcaseanalyzer").exists():
            with pushdir(idir):
                log("building ethmutator")
                run("env CC=clang CXX=clang++ cargo build --release",
                    shell=True,
                    p=1)

        os.environ['PATH'] += f":{bdir!s}"

        if not shutil.which("efuzzcaseanalyzer"):
            loge("failed to locate/build ethmutator")

            return False

    if not config.eevm_path.exists():
        if config.install_dir.exists():
            p = config.install_dir / "src" / "eEVM"
            p2 = config.install_dir / "src" / "eEVM" / "fuzz"
            p3 = config.install_dir / "src" / "eEVM" / "src"
            if exist_all(p, p2, p3):
                log("previous EVM_PATH {config.eevm_path!s} not found - using guessed {p!s} instead",
                    level=logging.DEBUG)
                config.eevm_path = Path(p)

    if not config.eevm_path.exists():
        loge("failed to locate eEVM project directory")
        return False

    is_ramdisk, mntpoint = is_on_tmpfs(config.fuzz_dir)
    if mntpoint:
        log(f"located fuzz dir {config.fuzz_dir!s} on mount {mntpoint!s}",
            level=logging.DEBUG)
    else:
        logw("Could not locate fuzzing directory mount point")
    if not is_ramdisk:
        logw(f"Your fuzzing directory '{config.fuzz_dir!s}' is not"
             " located on a ramdisk"
             " - we recommend to use a big tmpfs or zram device for"
             " the fuzzing directory.")

    return True
