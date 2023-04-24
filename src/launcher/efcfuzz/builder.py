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
import json
import logging
import os
import pathlib
import random
import re
import select
import shutil
import subprocess as sp
import sys
import tarfile
from pathlib import Path
from typing import List, Optional

# 3rd party deps
import solcx

from .compile_eevm_state import translate_whole_state
from .dump_state_from_geth import create_eevm_state
from .make_dict_for_state import make_dict_for_state
# local imports
from .state import dump_state_json, dump_state_msgpack
from .utils import (is_git_dir, log, loge, logw, normalize_ethereum_address,
                    pushdir, realpath, run, sudo)

DEFAULT_STATE_FILE = "./full-state.load.state.msgpack"
DEFAULT_STATE_DICT = "./full-state.dict"

DEFAULT_TARGET_NAME = "./target_name"
DEFAULT_MULTI_ADDRLIST = "./addr_list.txt"
DEFAULT_MULTI_ABILIST = "./abi_list.txt"

CONTRACT_REGEX = re.compile(r"contract ([a-zA-Z][a-zA-Z0-9_]*)\s*\{{0,1}.*")
PRAGMA_REGEX = re.compile(
    r"pragma solidity [\^]?([0-9]+\.[0-9]+(\.[0-9]+)?)\s*;")


def extract_build(build: Path):
    if not build.exists():
        return False

    if len(build.suffixes) >= 2 and build.suffixes[-2:] == [".tar", ".xz"]:
        shutil.unpack_archive(build)
    elif build.is_dir():
        shutil.copytree(build,
                        ".",
                        ignore_dangling_symlinks=True,
                        dirs_exist_ok=True)
    else:
        return False

    return True


def reset_evm_repo(evm_dir):
    log("resetting evm repo")

    with pushdir(evm_dir):

        Path(DEFAULT_STATE_FILE).unlink(True)
        Path(DEFAULT_STATE_FILE.replace(".msgpack", ".json")).unlink(True)
        Path(DEFAULT_STATE_DICT).unlink(True)
        Path(DEFAULT_TARGET_NAME).unlink(True)
        Path(DEFAULT_MULTI_ADDRLIST).unlink(True)
        Path(DEFAULT_MULTI_ABILIST).unlink(True)

        fuzz_out = Path("./fuzz/out")

        if fuzz_out.exists():
            for p in fuzz_out.iterdir():
                if p.is_symlink() or p.is_file():
                    p.unlink()
                elif p.is_dir() and not p.is_symlink():
                    try:
                        shutil.rmtree(p)
                    except OSError:
                        sudo("umount", p, shell=True)
                        try:
                            shutil.rmtree(p)
                        except OSError:
                            pass
            try:
                shutil.rmtree(fuzz_out)
            except OSError:
                logw(
                    f"failed to properly cleanup eEVM directory {evm_dir} - failed to removed {fuzz_out}"
                )

        def remove_unwanted_dirs_from_srctree():
            """
            Remove all the directories, which are recreated with evm2cpp
            anyway. Make sure that the respective directories do exist.
            """
            pathsi = map(
                Path,
                ("./contracts", "./fuzz/build", "./fuzz/abi", "./fuzz/dict"))
            for p in pathsi:
                if p.exists():
                    shutil.rmtree(p)
                p.mkdir(parents=True, exist_ok=True)

        if is_git_dir():
            log("restoring from git")
            run("git reset --hard", shell=True)
            remove_unwanted_dirs_from_srctree()
            run("git checkout .", shell=True)
            remove_unwanted_dirs_from_srctree()

            return True
        else:
            eevm_tarball = realpath(evm_dir) / ".." / "eEVM.orig.tar.xz"

            if eevm_tarball.exists():
                log("restoring from tarball")

                p = Path(evm_dir)
                for d in p.iterdir():
                    if d.is_dir():
                        shutil.rmtree(str(d))
                    else:
                        d.unlink()

                shutil.unpack_archive(eevm_tarball,
                                      extract_dir=str(
                                          evm_dir.parent.absolute()))

                remove_unwanted_dirs_from_srctree()

                if (evm_dir / "contracts").exists() and (evm_dir /
                                                         "fuzz").exists():
                    return True

                dirlist = ""
                if evm_dir.exists() and evm_dir.is_dir():
                    dirlist = "; ".join(map(str, evm_dir.iterdir()))
                logw(
                    f"critical files missing in directory {evm_dir} (got {dirlist})"
                )
                return False
            else:
                log("failed to reset eEVM repository", logging.WARNING)

                return False

    return False


def quick_build(config,
                target: str,
                evm_dir: Path,
                log_path: Optional[Path] = None,
                fuzzer: str = "afuzz"):
    with pushdir(evm_dir):
        cmd: List[str] = []
        timebin = shutil.which("time")

        if timebin:
            cmd = ["/usr/bin/time", "-v"]

        cmd += ["./quick-build.sh", fuzzer, str(target)]
        log("launching command:", *cmd, level=logging.DEBUG)
        proc = sp.Popen(cmd, stdout=sp.PIPE, stderr=sp.PIPE)

        buildlog_fp = None
        buildlog_mem = []
        try:
            if log_path:
                if not log_path.parent.exists():
                    os.makedirs(log_path.parent, exist_ok=True)
                buildlog_fp = log_path.open("wb")
            fno_out = proc.stdout.fileno()
            fno_err = proc.stderr.fileno()
            if fno_err != fno_out:
                filenos = (fno_err, fno_out)
            else:
                filenos = (fno_err, )

            while proc.poll() is None:
                r, _w, _e = select.select([fno_out, fno_err], [], [], 10)
                for fileno in filenos:
                    if fileno in r:
                        buf = os.read(fileno, 1024)

                        if log_path:
                            buildlog_fp.write(buf)

                        if config.verbose_build or config.verbose:
                            sys.stdout.buffer.write(buf)
                            sys.stdout.flush()
                        else:
                            buildlog_mem.append(buf)
        finally:
            if buildlog_fp:
                buildlog_fp.close()

        exitcode = proc.poll()
        if exitcode != 0:
            if buildlog_mem and not log_path:
                bm = b"".join(buildlog_mem)
                try:
                    bm = bm.decode("utf-8")
                except UnicodeDecodeError:
                    pass
                loge(
                    f"buildlog of failing quick-build.sh (exitcode {exitcode!s}):\n\n{bm}"
                )
            elif log_path:
                buildlog_mem_tail = ""
                if buildlog_mem:
                    buildlog_mem_tail = (
                        b":\n\n---- snip ----\n" +
                        (b"\n".join(b"".join(buildlog_mem).split(b"\n")[-7:])))
                    try:
                        buildlog_mem_tail = buildlog_mem_tail.decode("utf-8")
                    except UnicodeDecodeError:
                        pass
                loge(
                    f"build of eEVM/native smart contract failed (exitcode {exitcode!s}) see {log_path!s} for a full log{buildlog_mem_tail}"
                )
            else:
                loge(
                    f"build of eEVM/native smart contract failed (exitcode {exitcode!s})"
                )

        log("eEVM / native code build finished")
        return exitcode == 0


def make_build_out(outpath: Path, evm_dir: Path, additional_filter=None):
    if outpath.exists():
        if outpath.is_file():
            outpath.unlink()
        elif outpath.is_dir():
            shutil.rmtree(outpath)

    os.makedirs(outpath.parent, exist_ok=True)

    suff = outpath.suffixes
    containing_dir = outpath.parent
    os.makedirs(containing_dir, exist_ok=True)

    EXCLUDE_FILES = set([
        '.git', '.cache', '.ccache', '.github', '.gitignore', '.gitlab-ci.yml'
    ])
    if len(suff) >= 2 and suff[-2:] == [".tar", ".xz"]:
        log("compressing build to", outpath, "from", evm_dir)

        def tar_filter(x):
            if x.name in EXCLUDE_FILES:
                return None

            if additional_filter:
                return x if additional_filter(x.name) else None

            return x

        with pushdir(evm_dir):
            outpath = Path(outpath)
            if not outpath.parent.exists():
                outpath.parent.mkdir(parents=True, exist_ok=True)
            with tarfile.open(str(outpath), 'w:xz') as tf:
                tf.add(".", filter=tar_filter)
    else:
        log("copying build to", outpath, "from", evm_dir)
        if outpath.exists():
            shutil.rmtree(outpath)
        if not outpath.parent.exists():
            os.makedirs(outpath.parent, exist_ok=True)

        def ignore_func(src, names):
            ignore = set()
            for name in names:
                if name in EXCLUDE_FILES:
                    ignore.add(name)
                if additional_filter and not additional_filter(name):
                    ignore.add(name)
            return list(ignore)

        shutil.copytree(evm_dir,
                        outpath,
                        ignore=ignore_func,
                        symlinks=False,
                        ignore_dangling_symlinks=True)


def create_state_build(config,
                       target_id: str,
                       addresses: List[str],
                       outpath: Path,
                       evm_dir: Path,
                       state_path: str = DEFAULT_STATE_FILE):
    target = normalize_ethereum_address(addresses[0])
    state = create_eevm_state(
        addresses,
        scan_address_deps=config.include_address_deps,
        rate_limit=config.geth_rate_limit,
        consider_all_storage_keys=config.include_mapping_deps)

    target_i = int(target, 16)
    if state.exists(target_i):
        code = state[target_i].code
        if not code:
            loge("target contract", target,
                 "found in state export, but does not have code (len is",
                 (len(code) if code else 0),
                 ") at the current block (not yet, or selfdestruct)")
            return False
    else:
        loge(
            "target contract", target,
            "not found in state export - maybe the account does not exist "
            "at the current block (not yet, or selfdestruct)")
        return False

    if not reset_evm_repo(evm_dir):
        loge("failed to reset eEVM repo - stopping build")
        return False

    with pushdir(evm_dir):
        with open(DEFAULT_TARGET_NAME, "w") as f:
            f.write(target)

        if config.multi_target and config.multi_target_addresses:
            with open(DEFAULT_MULTI_ADDRLIST, "w") as f:
                f.write(",".join(
                    map(normalize_ethereum_address,
                        config.multi_target_addresses)))
            with open(DEFAULT_MULTI_ABILIST, "w") as f:
                abipaths = [(Path("./fuzz/abi") / f"{addr}.abi")
                            for addr in map(normalize_ethereum_address,
                                            config.multi_target_addresses)]
                if all(map(lambda x: x.exists(), abipaths)):
                    f.write(",".join(map(str, abipaths)))
                else:
                    logw("could not write `abi_list.txt` in build path,"
                         " because of some missing ABI file")

        state_pathp = pathlib.Path(state_path)
        log("saving state to", state_path, level=logging.DEBUG)
        if str(state_pathp.name).endswith(".json"):
            dump_state_json(state, state_pathp)
        else:
            dump_state_msgpack(state, state_pathp)

        fsize = state_pathp.stat().st_size  # os.path.getsize(str(state_path))
        log("saved state to", state_path, "with", state.size(),
            "accounts and size ", fsize, " bytes")

        log("translating all contracts to C++")
        translate_whole_state(state, evm_dir)

        log("creating combined dictionary")
        d = make_dict_for_state(state, evm_dir, addresses,
                                config.dict_max_length)
        log(f"combined dictionary of length {len(d)}", level=logging.DEBUG)
        if len(d) > config.dict_max_length:
            logw(("truncating the dictionary, because it" +
                  " exceeds the default length"), config.dict_max_length,
                 "with provided length", len(d))
            d = list(d)
            d = d[:config.dict_max_length]
        with open(DEFAULT_STATE_DICT, "w") as f:
            f.write(f"# combined dictionary for state {state_path}\n\n")
            f.write("\n".join(map(str, d)))

        log(f"building eEVM with fuzz target {target}")
        # run(f"./quick-build.sh afuzz {target}", shell=True, p=True)
        log_path = outpath.with_suffix(".build.log")
        res = quick_build(config, target, evm_dir, log_path=log_path)
        if not res:
            return False

    make_build_out(outpath, evm_dir)
    return True


def run_evm2cpp_cj(config, name, source, evm_dir):
    cmd = ['evm2cpp', '-e', evm_dir]
    if config.translate_all:
        cmd.append('--translate-all')
    else:
        cmd.append(name)
    cmd.append(source)
    log("running evm2cpp: ", *cmd)
    r = run(*cmd)

    return r


def run_evm2cpp_binrt(config, name, source, evm_dir):
    cmd = ['evm2cpp', '-e', evm_dir]

    if config.abi:
        if os.path.exists(config.abi):
            cmd.extend(["--abi", config.abi])
        else:
            logw(f"abi path {config.abi} does not exist!")

    if config.translate_all:
        cmd.append('--translate-all')
    else:
        cmd.append(name)
    cmd.append(source)

    if config.bin_deploy:
        cmd.append(config.bin_deploy)

    log("running evm2cpp: ", *cmd)
    r = run(*cmd)

    return r


def create_runtime_build(config, name: str, outpath: Path, evm_dir: Path):
    source = config.bin_runtime

    if not reset_evm_repo(evm_dir):
        loge("failed to reset eEVM repo - stopping build")
        return False

    if str(source).endswith(".combined.json"):
        r = run_evm2cpp_cj(config, name, source, evm_dir)
    else:
        r = run_evm2cpp_binrt(config, name, source, evm_dir)

    # we store the bytecode
    shutil.copy(source, evm_dir / "contracts")

    if r.returncode != 0:
        loge(
            f"Failed to translate contract code to C++ (evm2cpp exit code {r.returncode})"
        )
        return False

    with pushdir(evm_dir):
        with open("./target_name", "w") as f:
            f.write(name)

        log(f"building eEVM with fuzz target {name}")
        log_path = outpath.with_suffix(".build.log")
        res = quick_build(config, name, evm_dir, log_path=log_path)
        if not res:
            return False

    make_build_out(outpath, evm_dir, lambda x: None
                   if "full-state" in x else x)

    return True


def compile_source(config, sources, outpath):
    with open(sources[0]) as f:
        first_source = list(map(str.strip, f.readlines()))

    name = None

    if config.name:
        name = config.name
    else:

        def normalize_name(s):
            s = s.lower()
            s = s.strip()
            s = s.replace("_", "")

            return s

        src = Path(sources[0])
        bname = str(src.name).split(".")[0]
        bname = normalize_name(bname)

        for line in first_source:
            m = CONTRACT_REGEX.search(line)

            if m:
                name = m.groups()[0]

                if normalize_name(name) == bname:
                    break

        log(f"guessing contract name: '{name}'")

    if not name:
        loge(f"failed to infer name from args or {sources[0]}")

        return None

    if config.solc_version != "auto":
        sol_version = config.solc_version
    else:
        sol_version = "0.7.6"

        for line in first_source:
            m = PRAGMA_REGEX.search(line)

            if m:
                sol_version = m.groups()[0]
                log("installing solidity version with solcx - if needed")
                v = solcx.install_solc_pragma(line)
                sol_version = str(v.truncate())

                break

        i_sol_version = list(map(int, sol_version.strip().split(".")))

        if i_sol_version[0] == 0 and i_sol_version[1] <= 4:
            if i_sol_version[1] < 3 or (i_sol_version[1] == 4
                                        and i_sol_version[2] <= 9):
                logw("unsupported solidity version", sol_version,
                     "- switching to newer solidity 0.4.26")
                i_sol_version = [0, 4, 26]

        sol_version = ".".join(map(str, i_sol_version))
    solcx.install_solc(sol_version)
    log(f"compiling sources {list(map(str,sources))} with solc v{sol_version}")
    r = solcx.compile_files(sources,
                            output_values=["abi", "bin", "bin-runtime"],
                            solc_version=sol_version,
                            optimize=True)

    log(f"compiled with solcx {r.keys()}", level=logging.DEBUG)

    if not r:
        return None

    # a bit of sanitization. Older solcs included the ABI as a string into the
    # combined.json output. Newer solcs include it as JSON into the
    # combined.json. However, evm2cpp can only handle the approach of the older
    # ones. Whatever, py-solc-x does, we need to make sure that we use the old
    # ways, s.t. evm2cpp does not break.
    for contract, data in r.items():
        if not isinstance(data['abi'], str):
            data['abi'] = json.dumps(data['abi'])

    # we create a solc combined.json output-compatible output json, which
    # includes some additional field to the output provided by py-solc-x.
    with open(outpath, "w") as f:
        o = {
            'contracts': r,
            'sourceList': list(map(str, sources)),
            'version': sol_version
        }
        json.dump(o, f)

    return name
