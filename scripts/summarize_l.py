#!/usr/bin/env python

import csv
import glob
import json
import os
import re
import sys
import tarfile
import traceback
from pathlib import Path
try:
    import msgpack
except ImportError:
    msgpack = None

FILTER_OUT = list(map(re.compile, ["consecutive deduplicated"]))

assert len(
    sys.argv
) == 3, "need two arguments: output file; and glob for the results dirs"

WALL_CLOCK_KEY = "wall clock time (h:)m:ss"
csv_header_fields = ["contract", 'status', WALL_CLOCK_KEY, "input-type", 'abi']
additional_headers = set()

csv_entries = []

for run_dir in glob.glob(sys.argv[2]):
    print("run dir:", run_dir)
    results_files = os.path.join(run_dir, "*.tar.xz")

    for fuzzults in glob.glob(results_files):
        path = Path(fuzzults)
        contract = str(path.name).split(".")[0]
        if not contract:
            print("what no contract id for file", path, file=sys.stderr)
            continue

        r = {
            "contract": contract,
            'input-type': None,
            WALL_CLOCK_KEY: None,
            'abi': False,
        }

        if not path.exists() or not tarfile.is_tarfile(fuzzults):
            r['status'] = 'failure'
            csv_entries.append(r)
            continue

        try:
            with tarfile.open(fuzzults) as tf:
                alldone = 0

                for tfinfo in tf:
                    if tfinfo.name == "./bugtypes":
                        alldone += 1
                        contents = tf.extractfile(tfinfo).read()
                        count = len(set(contents.strip().split(b"\n")))
                        k = "bugtypes"
                        r[k] = count

                    elif tfinfo.name.endswith("full-state.load.state.msgpack"):
                        alldone += 1
                        r['input-type'] = 'live-state'

                        if msgpack is None:
                            print("[WARNING] ignoring msgpack sate")
                            continue

                        try:
                            state = msgpack.load(tf.extractfile(tfinfo))
                            accounts = state[5]
                            num_accounts = len(accounts)
                            r['state_accounts'] = num_accounts
                            max_st_size = 0
                            max_code_size = 0
                            average_st_size = 0
                            average_code_size = 0
                            for acc in accounts.values():
                                # code size
                                code_size = (len(acc[2]) / 2) - 1
                                max_code_size = max(code_size, max_code_size)
                                average_code_size += code_size
                                # storage size
                                st_size = len(acc[3])
                                max_st_size = max(max_st_size, st_size)
                                average_st_size += st_size

                            average_st_size /= num_accounts
                            average_code_size /= num_accounts
                            r['state_average_storage_size'] = average_st_size
                            r['state_max_storage_size'] = max_st_size
                            r['state_average_code_size'] = average_code_size
                            r['state_max_code_size'] = max_code_size
                        except Exception as e:
                            traceback.print_exc()
                            print("failed to parse json in",
                                  tfinfo,
                                  "due to",
                                  e,
                                  file=sys.stderr)

                    elif tfinfo.name.endswith("full-state.load.state.json"):
                        alldone += 1
                        r['input-type'] = 'live-state'

                        try:
                            state = json.load(tf.extractfile(tfinfo))
                            num_accounts = len(state['accounts'])
                            r['state_accounts'] = num_accounts
                            max_st_size = 0
                            max_code_size = 0
                            average_st_size = 0
                            average_code_size = 0
                            for acc in state['accounts']:
                                st_size = len(acc[1][1])
                                max_st_size = max(max_st_size, st_size)
                                average_st_size += st_size
                                code_size = (len(acc[1][0]['code']) / 2) - 1
                                max_code_size = max(code_size, max_code_size)
                                average_code_size += code_size

                            average_st_size /= num_accounts
                            average_code_size /= num_accounts
                            r['state_average_storage_size'] = average_st_size
                            r['state_max_storage_size'] = max_st_size
                            r['state_average_code_size'] = average_code_size
                            r['state_max_code_size'] = max_code_size
                        except Exception as e:
                            traceback.print_exc()
                            print("failed to parse json in",
                                  tfinfo,
                                  "due to",
                                  e,
                                  file=sys.stderr)

                    elif tfinfo.name == "./contract.abi":
                        alldone += 1
                        r['abi'] = True

                    elif tfinfo.name == "./coverage-percent-all.evmcov":
                        alldone += 1
                        contents = tf.extractfile(tfinfo).read().strip()
                        try:
                            contents = contents.decode("utf-8")
                        except:
                            pass
                        k = 'coverage'
                        r[k] = contents.strip()

                    elif tfinfo.name == "./bugs":
                        alldone += 1
                        contents = tf.extractfile(tfinfo).read().strip()
                        try:
                            contents = contents.decode("utf-8")
                        except:
                            pass
                        k = "bugs"
                        additional_headers.add(k)
                        r[k] = contents.strip()

                    elif tfinfo.name == "./afl.time":
                        alldone += 1
                        contents = tf.extractfile(tfinfo).read().strip()
                        try:
                            contents = contents.decode("utf-8")
                        except:
                            pass
                        try:
                            line = next(line for line in contents.splitlines()
                                        if "wall clock" in line)
                            line = line.strip()
                            k = WALL_CLOCK_KEY
                            v = line.split("): ")[1]
                            r[k] = v
                            additional_headers.add(k)
                        except StopIteration:
                            print("[ERROR]", f"'{tfinfo.name}'", "is empty")

                    elif tfinfo.name == "./crashes_tx_summary":
                        alldone += 1
                        contents = tf.extractfile(tfinfo).read().strip()
                        contents = contents.decode("utf-8")
                        for line in contents.splitlines():
                            if "Number of fuzzcases" in line:
                                nr = line.split(":")[1].strip()
                                nr = int(nr)
                                r['crashes'] = nr
                                break

                    elif tfinfo.name == "./queue_tx_summary":
                        alldone += 1
                        contents = tf.extractfile(tfinfo).read().strip()
                        contents = contents.decode("utf-8")
                        for line in contents.splitlines():
                            if "Number of fuzzcases" in line:
                                nr = line.split(":")[1].strip()
                                nr = int(nr)
                                r['queue'] = nr
                                break

                    elif tfinfo.name == "./default/fuzzer_stats":
                        alldone += 1
                        contents = tf.extractfile(tfinfo).read().strip()
                        contents = contents.decode("utf-8")
                        fuzzer_stats = {}
                        for line in contents.splitlines():
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
                        else:
                            exec_sec = execs_done

                        r['execs_per_sec'] = exec_sec
                        r['run_unix'] = run_unix
                        r['execs'] = execs_done
            r['status'] = 'success'
        except EOFError as e:
            r['status'] = 'failure'
            print("reached EOF on file", fuzzults, "due to", repr(e), file=sys.stderr)

        for k in r.keys():
            if k not in csv_header_fields:
                additional_headers.add(k)
        csv_entries.append(r)
        print(".", end="", flush=True)
print()

csv_header_fields = (csv_header_fields + list(additional_headers))

with open(os.path.abspath(sys.argv[1]), "w", newline='') as f:
    csvw = csv.DictWriter(f, fieldnames=(csv_header_fields))
    csvw.writeheader()

    for r in sorted(csv_entries, key=lambda d: (d['status'], d['contract'])):
        csvw.writerow(r)
        print(r['contract'], "=>", "finding? => ",
              len(r.get("bugs", "")) > 0, r.get(WALL_CLOCK_KEY, "???"))
