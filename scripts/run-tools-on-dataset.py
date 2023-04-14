#!/usr/bin/env python3

import glob
import json
import os
import re
import shutil
import subprocess as sp
import sys
import time
from multiprocessing import cpu_count
from time import sleep
from typing import List

import psutil

#################### configuration ####################

# global max number of repetitions; can be lowered per-tool
REPETITIONS = 30
# used for multi
GLOBAL_TIMEOUT = 60 * 60 * 48
# used for throughput
# GLOBAL_TIMEOUT = 60 * 10
MAX_CPU = (cpu_count() // 2)  # half to avoid running on hyperthreads

# default SMT/symex settings passed to all symex-based tools
SOLVER_TIMEOUT_SEC = 1920
SOLVER_TIMEOUT_MILLIS = SOLVER_TIMEOUT_SEC * 1000
# TX_BOUND = 16
TX_BOUND = 32

# REPETITIONS per-tool
# change these to 0 to disable running tools
TOOLS = {
    'smartian': 10,
    'verismart': 0,
    'manticore': 0,
    'maian': 0,
    'echidna2': 0,
    'echidnap.c4': 0,
    'manticore.c4': 0,
    'confuzzius': 0,
    'echidna': 0,
    'ilf': 0,
    'manticorepypy': 0,
    'manticorepypy.c8': 0,
    'confuzziuspypy': 0,
    'teether': 0,
    'ethbmc': 0,
    'echidnaparade': 0,
}

# default cpus per container, can be overriden...
CPUS = 1

######################################################


def realpath(p):
    return os.path.abspath(os.path.expanduser(p))


def container_state(name):
    try:
        x = sp.check_output([DOCKER, "inspect", name])
        x = json.loads(x)

        if len(x) == 0:
            return None

        if not x[0]:
            return None

        if 'State' not in x[0]:
            print("weird docker-inspect json response", x[0])

        return x[0]['State']
    except sp.CalledProcessError:
        return None


def do_sleep(sec, printme=True):
    if printme:
        print(f"[S] sleeping for {sec} seconds ({sec / 60} minutes)")
    sleep(sec)


CLEAN_RUN = bool(os.environ.get("CLEAN_RUN", 0))

DOCKER = None
try:
    sp.check_output(["docker", "--help"])
    DOCKER = "docker"
except FileNotFoundError:
    try:
        sp.check_output(["podman", "--help"])
        DOCKER = "podman"
    except FileNotFoundError:
        pass
assert DOCKER is not None, "No `docker` or `podman` binary found"


def docker(*args, allow_fail=True, print_cmd=False):
    try:
        if print_cmd:
            print("`", DOCKER, " ".join(args), "`")

        return sp.check_call([DOCKER] + list(map(str, args)))
    except sp.CalledProcessError:
        if not allow_fail:
            raise


def count_running_containers():
    return sp.check_output([DOCKER, "ps", "-q"]).count(b"\n")


def count_container_cpus_usage():
    running_container = [
        cid

        for cid in sp.check_output([DOCKER, "ps", "-q"]).strip().split(b"\n")

        if cid
    ]

    if not running_container:
        return 0

    x = sp.check_output([DOCKER, "inspect"] + running_container)
    x = json.loads(x)

    return sum(map(lambda c: int(c['HostConfig']['NanoCpus']) / 1000000000, x))


DATASET = realpath(sys.argv[1])
assert os.path.exists(DATASET)

DATASET_ID = os.path.basename(DATASET)

print("[+] building tools containers")
make_cmd = ["make", "-j", str(MAX_CPU)]

for t, n in TOOLS.items():
    if n > 0:
        if "." in t:
            t = t.split(".")[0]

        if t in ('echidna', 'manticore'):
            t = t + "prime"
        make_cmd.append(t)
sp.check_call(make_cmd, cwd="./docker/tools")

print("[+] running tools on", DATASET)

LAUNCHED_CONTAINERS: List[str] = []
CONTAINER_COUNTER = 0
DONE_CONTAINER_COUNTER = 0
STOP_CONTAINER_COUNTER = 0

OUT_DIR = realpath("./results/tools-" + os.path.basename(DATASET))


def stop_containers_overtime():
    global STOP_CONTAINER_COUNTER
    running = 0
    print("[+] checking ", len(LAUNCHED_CONTAINERS),
          "containers for being global timeout limit")

    for container in LAUNCHED_CONTAINERS:
        state = container_state(container)

        if not state:
            continue

        cstatus = state["Status"]
        startedat = state['StartedAt']

        if cstatus == "running":
            running += 1
            pid = state['Pid']
            cpid1 = psutil.Process(pid)
            runningtime = time.time() - cpid1.create_time()

            print(container, "started at", startedat, "(running time",
                  runningtime, "seconds vs", GLOBAL_TIMEOUT, "sec timeout)")

            if runningtime > GLOBAL_TIMEOUT:
                print(container, "is over ime!!!!")
                docker("stop", "-t", 120, container)
                sleep(10)
                STOP_CONTAINER_COUNTER += 1

    print("... done (tracked running tasks:", running, "; total tracked:",
          len(LAUNCHED_CONTAINERS), "; total up containers",
          count_running_containers())

    return running


_DOCKER_QUEUE = []


def docker_queue(*args, **kwargs):
    global _DOCKER_QUEUE
    global CONTAINER_COUNTER, DONE_CONTAINER_COUNTER

    if 'cpus' not in kwargs:
        kwargs['cpus'] = 1
    cpus_required = kwargs.get('cpus', 1)
    cpus_used = count_container_cpus_usage()

    if cpus_used + cpus_required <= MAX_CPU:
        if 'cpus' in kwargs:
            del kwargs['cpus']
        docker(*args, **kwargs)
        CONTAINER_COUNTER += 1
    else:
        cname = ""

        if "--name" in args:
            cname = args[args.index("--name") + 1]
        print("[Q] queueing container", cname, " at pos", len(_DOCKER_QUEUE))
        _DOCKER_QUEUE.append((args, kwargs))

        if len(_DOCKER_QUEUE) % 50 == 0:
            stop_containers_overtime()


def finish_docker_queue():
    global _DOCKER_QUEUE
    global CONTAINER_COUNTER, DONE_CONTAINER_COUNTER

    while _DOCKER_QUEUE:
        non_found = False
        cpus_used = count_container_cpus_usage()

        print("[+] Trying to schedule a container/task")
        print("CPUs used =>", cpus_used, "/", MAX_CPU)

        if cpus_used < MAX_CPU:
            for (i, (args, kwargs)) in enumerate(_DOCKER_QUEUE[::]):
                cpus_required = int(kwargs.get('cpus', 1))

                if cpus_used + cpus_required <= MAX_CPU:
                    print("[+] launching container with", cpus_required,
                          "cpus from queue - current cpus usage", cpus_used,
                          "/", MAX_CPU)

                    if 'cpus' in kwargs:
                        del kwargs['cpus']
                    docker(*args, **kwargs)
                    CONTAINER_COUNTER += 1
                    del _DOCKER_QUEUE[i]

                    break
            else:
                cpus_used = count_container_cpus_usage()

                if cpus_used < MAX_CPU:
                    print("[-] Found no container that can be scheduled")
                    non_found = True

        cpus_used = count_container_cpus_usage()

        if cpus_used == MAX_CPU or non_found:
            print("[+] CPU saturated. waiting...")
            print("current cpus usage", cpus_used, "/", MAX_CPU)
            print(count_running_containers(), "containers running")
            print(DONE_CONTAINER_COUNTER, "containers exited")
            print(len(_DOCKER_QUEUE), "containers queued")
            stop_containers_overtime()
            do_sleep(300)
            stop_containers_overtime()


def launch_in_docker(container, contract, runid, *args, cpus=CPUS):
    global CONTAINER_COUNTER, DONE_CONTAINER_COUNTER, LAUNCHED_CONTAINERS

    cname = f"tool-on-{DATASET_ID}.{container}.{contract}.{runid}"

    _cstate = container_state(cname)
    cstatus = None if _cstate is None else _cstate['Status']
    print("container", cname, "=>", cstatus)

    if CLEAN_RUN:
        docker("stop", cname)
        sleep(1)
        docker('rm', cname)
        cstatus = None
        sleep(1)

    if cstatus is None:

        print("[+] starting/queueinng next container", cname)
        args = map(str, args)
        docker_queue("run",
                     "--init",
                     "-v",
                     f"{OUT_DIR}:{OUT_DIR}:z",
                     "-v",
                     f"{DATASET}:{DATASET}:z",
                     "-w",
                     str(DATASET),
                     "--cpus",
                     str(cpus),
                     "-d",
                     "--name",
                     cname,
                     container,
                     *args,
                     print_cmd=True,
                     cpus=cpus)
        sleep(1)

        # CONTAINER_COUNTER += 1

    LAUNCHED_CONTAINERS.append(cname)

    if cstatus == "exited":
        DONE_CONTAINER_COUNTER += 1

    print("[+] tracking", len(LAUNCHED_CONTAINERS), "containers")


if CLEAN_RUN and os.path.exists(OUT_DIR):
    print("[W] cleaning out dir", OUT_DIR)
    shutil.rmtree(OUT_DIR)
os.makedirs(OUT_DIR, exist_ok=True)

CONTRACT_REGEX = re.compile(r"contract ([a-zA-Z][a-zA-Z0-9_]*).*")
PRAGMA_REGEX = re.compile(r"pragma solidity [\^]?([0-9]+\.[0-9]+\.[0-9]+)\s*;")

for i in range(1, REPETITIONS + 1):
    print("[+] repetition", i)

    for solpath in sorted(glob.glob(os.path.join(DATASET, "*.sol"))):
        sol = os.path.basename(solpath)
        file_base = os.path.splitext(sol)[0]

        contract = None  # os.path.splitext(sol)[0]
        sol_version = None  # "0.7.6"

        with open(solpath) as f:
            for line in f.readlines():
                m = CONTRACT_REGEX.search(line)

                if m:
                    contract = m.groups()[0]

                m = PRAGMA_REGEX.search(line)

                if m and not sol_version:
                    sol_version = m.groups()[0]

        if not contract:
            contract = os.path.splitext(sol)[0]

        if not sol_version:
            sol_version = "0.7.6"

        i_sol_version = list(map(int, sol_version.strip().split(".")))

        if i_sol_version[0] == 0 and i_sol_version[1] <= 4:
            if i_sol_version[1] < 3 or (i_sol_version[1] == 4
                                        and i_sol_version[2] <= 9):
                print("[W] unsupported solidity version", sol_version,
                      "- switching to newer solidity 0.4.26")
                i_sol_version = [0, 4, 26]

        sol_version = ".".join(map(str, i_sol_version))

        print("[+] building contract", contract, "from", solpath,
              "with file basename", file_base, "solidity version", sol_version)
        wd_bak = os.getcwd()
        os.chdir(DATASET)
        sp.check_call([
            "make", file_base, f"{file_base}.combined.json",
            f"SOLC_VERSION={sol_version}"
        ],
                      cwd=DATASET)
        os.chdir(wd_bak)

        print("[+] launching tools")

        if i <= TOOLS.get('maian', 0):
            launch_in_docker("maian", file_base, i, "--max_inv", TX_BOUND,
                             "--solve_timeout", SOLVER_TIMEOUT_MILLIS, "-c",
                             "0", "--bytecode", f"./{contract}.bin-runtime")

        if i <= TOOLS.get('teether', 0):
            launch_in_docker("teether", file_base, i,
                             f"{contract}.bin-runtime", "0xcafecafe",
                             "0xdeadbeef", "+1")

        if i <= TOOLS.get('ethbmc', 0):
            sp.check_call(["make", f"{file_base}.ethbmc.yml"], cwd=DATASET)
            launch_in_docker("ethbmc", file_base, i, "--message-bound",
                             TX_BOUND, "--solver-timeout",
                             SOLVER_TIMEOUT_MILLIS, "--cores", 1,
                             f"./{file_base}.ethbmc.yml")

        if i <= TOOLS.get('ethbmc.c4', 0):
            launch_in_docker("ethbmc",
                             file_base,
                             f"c4.{i}",
                             "--message-bound",
                             TX_BOUND,
                             "--solver-timeout",
                             SOLVER_TIMEOUT_MILLIS,
                             "--cores",
                             4,
                             f"./{file_base}.ethbmc.yml",
                             cpus=4)

        if i <= TOOLS.get('manticore', 0):
            launch_in_docker("manticoreprime", contract, f"{i}", "--maxt",
                             TX_BOUND, "--smt.timeout", SOLVER_TIMEOUT_SEC,
                             "--timeout", GLOBAL_TIMEOUT, "--propre",
                             'echidna.*', "--solc", "/usr/bin/solc-0.7.6",
                             "--maxfail", 1, "--core.procs", "1",
                             "--core.mprocessing", "single", "--contract_name",
                             contract, "--workspace.dir", OUT_DIR,
                             "--workspace.prefix",
                             f"manticore_{contract}-normal_run-{i}_", sol)

            if False:
                launch_in_docker(
                    "manticoreprime", contract, f"thorough.{i}", "--maxt",
                    TX_BOUND, "--smt.timeout", SOLVER_TIMEOUT_SEC, "--timeout",
                    GLOBAL_TIMEOUT, "--propre", 'echidna.*', "--solc",
                    "/usr/bin/solc-0.7.6", "--maxfail", 1, "--core.procs", "1",
                    "--thorough-mode", "--core.mprocessing", "single",
                    "--contract_name", contract, "--workspace.dir", OUT_DIR,
                    "--workspace.prefix",
                    f"manticore_{contract}-normal_run-{i}_", sol)

        for cores in (4, 8):
            cid = f"c{cores}"

            if i <= TOOLS.get(f'manticore.{cid}', 0):
                launch_in_docker("manticoreprime",
                                 contract,
                                 f"{cid}.{i}",
                                 "--maxt",
                                 TX_BOUND,
                                 "--smt.timeout",
                                 SOLVER_TIMEOUT_SEC,
                                 "--timeout",
                                 GLOBAL_TIMEOUT,
                                 "--propre",
                                 'echidna.*',
                                 "--solc",
                                 "/usr/bin/solc-0.7.6",
                                 "--maxfail",
                                 1,
                                 "--core.procs",
                                 cores,
                                 "--core.mprocessing",
                                 "multiprocessing",
                                 "--contract_name",
                                 contract,
                                 "--workspace.dir",
                                 OUT_DIR,
                                 "--workspace.prefix",
                                 f"manticore-{cid}_{contract}_run{i}_",
                                 sol,
                                 cpus=cores)

        if i <= TOOLS.get('manticorepypy', 0):
            launch_in_docker("manticorepypy",
                             contract,
                             f"{i}",
                             "--maxt",
                             TX_BOUND,
                             "--smt.timeout",
                             SOLVER_TIMEOUT_SEC,
                             "--timeout",
                             GLOBAL_TIMEOUT,
                             "--propre",
                             'echidna.*',
                             "--solc",
                             "/usr/bin/solc-0.7.6",
                             "--maxfail",
                             1,
                             "--core.mprocessing",
                             "single",
                             "--core.procs",
                             "1",
                             "--contract_name",
                             contract,
                             "--workspace.dir",
                             OUT_DIR,
                             "--workspace.prefix",
                             f"manticorepypy-{contract}_run{i}_",
                             sol,
                             cpus=1)

        if i <= TOOLS.get('manticorepypy.c8', 0):
            launch_in_docker("manticorepypy",
                             contract,
                             f"c8.{i}",
                             "--maxt",
                             TX_BOUND,
                             "--smt.timeout",
                             SOLVER_TIMEOUT_SEC,
                             "--timeout",
                             GLOBAL_TIMEOUT,
                             "--propre",
                             'echidna.*',
                             "--solc",
                             "/usr/bin/solc-0.7.6",
                             "--maxfail",
                             1,
                             "--core.procs",
                             8,
                             "--contract_name",
                             contract,
                             "--workspace.dir",
                             OUT_DIR,
                             "--workspace.prefix",
                             f"manticorepypy-c8_{contract}_run{i}_",
                             sol,
                             cpus=8)

        if i <= TOOLS.get('echidna', 0):
            echidna_conf = os.path.join(
                OUT_DIR, f"echidna_{file_base}_run{i}.config.yml")
            with open(echidna_conf, "w") as f:
                f.write(f"""
stopOnFail: true
coverage: true
timeout: {GLOBAL_TIMEOUT}
testLimit: 4294967296
""")

            launch_in_docker(
                "echidnaprime", file_base, i, "--contract", contract,
                "--crytic-args", f"--solc solc-{sol_version}", "--corpus-dir",
                os.path.join(OUT_DIR, f"echidna_{file_base}_run{i}"),
                "--config", echidna_conf, sol)

        if i <= TOOLS.get('echidna2', 0):
            echidna_conf = os.path.join(
                OUT_DIR, f"echidna2_{file_base}_run{i}.config.yml")
            with open(echidna_conf, "w") as f:
                f.write(f"""
stopOnFail: true
coverage: true
timeout: {GLOBAL_TIMEOUT}
testLimit: 4294967296
""")

            launch_in_docker(
                "echidna2", file_base, i, "--contract", contract,
                "--crytic-args", f"--solc solc-{sol_version}", "--corpus-dir",
                os.path.join(OUT_DIR, f"echidna_{file_base}_run{i}"),
                "--config", echidna_conf, sol)

        for cf in ('confuzzius', 'confuzziuspypy'):
            if i <= TOOLS.get(cf, 0):
                if "throughput" in DATASET:
                    launch_in_docker(
                        cf,
                        file_base,
                        i,
                        "--source",
                        f"{file_base}.combined.json",
                        "--timeout",
                        GLOBAL_TIMEOUT,
                        "--results",
                        os.path.join(
                            OUT_DIR,
                            f"confuzzius_{file_base}_run{i}_results.json"),
                        "--solc",
                        f"v{sol_version}",
                        "--contract",
                        contract,
                        "--disable-detectors",
                        "all",
                    )
                else:
                    launch_in_docker(
                        cf,
                        file_base,
                        i,
                        "--source",
                        f"{file_base}.combined.json",
                        "--timeout",
                        GLOBAL_TIMEOUT,
                        "--results",
                        os.path.join(
                            OUT_DIR,
                            f"confuzzius_{file_base}_run{i}_results.json"),
                        "--run-until-first-bug",
                        "--max-individual-length",
                        TX_BOUND,
                        "--solc",
                        f"v{sol_version}",
                        "--evm",
                        "homestead",
                        "--contract",
                        contract,
                        # "--disable-detectors", "assertion_fail,integer_overflow,transaction_order_dependency",
                        "--disable-detectors",
                        "all",
                        "--enable-detectors",
                        ("selfdestruct" if "multi" in DATASET else "selfdestruct,leaking_ether,unsafe_delegatecall,reentrancy")
                        # "--disable-detectors", "all", "--enable-detectors", "reentrancy"
                    )

        # run parade only on justlen. excluding functions from the other
        # testcases doesn't make sense
        if "justlen" in sol:
            if i <= TOOLS.get('echidnaparade', 0):
                launch_in_docker(
                    "echidnaparade", file_base, i, "--contract", contract,
                    "--name",
                    os.path.join(OUT_DIR,
                                 f"echidna-parade_run{i}_{file_base}"),
                    "--ncores", CPUS, "--timeout", GLOBAL_TIMEOUT, "--no-wait",
                    "--bench-until-first-fail", sol)

            for cores in (4, 8):
                cid = f"c{cores}"
                if i <= TOOLS.get(f'echidnaparade.{cid}', 0):
                    launch_in_docker(
                        "echidnaparade",
                        file_base,
                        f"{cid}.{i}",
                        "--contract",
                        contract,
                        "--name",
                        os.path.join(
                            OUT_DIR,
                            f"echidna-parade-{cid}_run{i}_{file_base}"),
                        "--ncores",
                        cores,
                        "--timeout",
                        GLOBAL_TIMEOUT,
                        "--no-wait",
                        "--bench-until-first-fail",
                        sol,
                        cpus=cores)

        for cores in (4, 8):
            cid = f"c{cores}"
            if i <= TOOLS.get(f'echidnap.{cid}', 0):
                launch_in_docker("echidnaparade",
                                 file_base,
                                 f"p1.{cid}.{i}",
                                 "--contract",
                                 contract,
                                 "--name",
                                 os.path.join(
                                     OUT_DIR,
                                     f"echidnap-{cid}_run{i}_{contract}"),
                                 "--ncores",
                                 cores,
                                 "--timeout",
                                 GLOBAL_TIMEOUT,
                                 "--no-wait",
                                 "--prob",
                                 1,
                                 "--bench-until-first-fail",
                                 sol,
                                 cpus=cores)

        if i <= TOOLS.get('ilf', 0):
            # sp.check_call([], cwd=DATASET)
            # launch_in_docker("ilf", file_base)
            raise NotImplementedError("not yet done")

        if i <= TOOLS.get('verismart', 0):
            # verismart seems to write the resuls to the dirs "output" and
            # "validation-files" in the current working dir also those dirs
            # must exist or otherwise there will be an exception/error so we
            # create those directories and symlink them in the out dir
            for fpath in ("validation-files", "output"):
                vs_in_dataset = os.path.abspath(os.path.join(DATASET, fpath))
                os.makedirs(vs_in_dataset, exist_ok=True)
                os.makedirs(os.path.join(OUT_DIR, "verismart"), exist_ok=True)
                vs_in_outdir = os.path.abspath(
                    os.path.join(OUT_DIR, "verismart", fpath))
                if not os.path.exists(vs_in_outdir):
                    os.symlink(vs_in_dataset, vs_in_outdir)
            launch_in_docker(
                "verismart",
                file_base,
                i,
                "-verbose",
                "-report",
                # outdir seems unused for exploit mode
                # "-outdir",
                # verismart_out_dir,
                "-input",
                sol,
                # solv seems problematic; can't find other solc versions in the container?
                # "-solv", sol_version,
                "-contract_init_eth",
                100,
                "-z3timeout",
                SOLVER_TIMEOUT_MILLIS,
                "-exploit_timeout",
                GLOBAL_TIMEOUT,
                "-tdepth",
                TX_BOUND,
                "-mode",
                "exploit",
                "kill")

        if i <= TOOLS.get('smartian', 0):
            launch_in_docker(
                "smartian", file_base, i, "fuzz", "-p",
                f"./{contract}.bin", "-a", f"./{contract}.abi", "-t",
                GLOBAL_TIMEOUT, "--benchtobug", "-o",
                os.path.join(OUT_DIR, f"smartian_{contract}_run{i}"))

print("[+] all containers queueed")
print(CONTAINER_COUNTER, "containers launched;", DONE_CONTAINER_COUNTER,
      "containers previously exited", len(_DOCKER_QUEUE),
      "containers currently queued")
print(count_running_containers(), "containers running")

finish_docker_queue()

print(CONTAINER_COUNTER, "containers launched;", DONE_CONTAINER_COUNTER,
      "containers previously exited", STOP_CONTAINER_COUNTER,
      "containers were stopped after overtime")
print(count_running_containers(), "containers running")
print("[+] waiting for container termination")

while stop_containers_overtime() > 0:
    print("...", end="")
    do_sleep(300)

do_sleep(10)

print("[+] finished, getting container outputs :)")

for container in LAUNCHED_CONTAINERS:
    print(f"{container}, ", end="")
    fname_base = container[(container.find(".") + 1):]
    with open(os.path.join(OUT_DIR, f"{fname_base}.log"), "w") as f:
        fout = f
        ferr = f
        try:
            sp.check_call([DOCKER, "logs", "-t", container],
                          stdout=fout,
                          stderr=ferr)
        except sp.CalledProcessError as e:
            print(f"[ERR] while processing output of '{container}': ({e!r})",
                  file=sys.stderr)
    with open(os.path.join(OUT_DIR, f"{fname_base}.status.json"), "w") as f:
        json.dump(container_state(container), f)

print()
print("[+] bye")
