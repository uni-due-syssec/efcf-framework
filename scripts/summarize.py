#!/usr/bin/env python

import os
import csv
import glob
import sys
import re
import tarfile

FILTER_OUT = list(map(re.compile, ["consecutive deduplicated"]))

assert len(
    sys.argv
) == 3, "need two arguments: output file; and glob for the results dirs"

csv_header_fields = ["contract", "mode", "status", "log"]
additional_headers = set()
WALL_CLOCK_KEY = "wall clock time (h:)m:ss"

csv_entries = []

for run_dir in glob.glob(sys.argv[2]):
    print("run dir:", run_dir)
    results_files = os.path.join(run_dir, "*.fuzz.status")

    for statusf in glob.glob(results_files):
        entry = statusf.replace("fuzz.status", "fuzz.results")
        file_base = os.path.basename(statusf)
        contract, mode = file_base.split(".")[:2]
        status = None
        with open(statusf) as f:
            status = f.read().strip()
        log = ""
        logfile = entry.replace(".results", ".log")

        if os.path.exists(logfile):
            if status != "success" and status != "running":
                with open(logfile) as f:
                    log = "\n".join(list(f.readlines())[-8:])
        else:
            log = "<NO LOG>"
        r = {"contract": contract, "mode": mode, "status": status, "log": log}

        if os.path.exists(entry):
            with open(entry) as f:
                for line in f.readlines():
                    if any(map(lambda r: r.search(line), FILTER_OUT)):
                        continue

                    try:
                        k, v = line.split(":")
                    except ValueError:
                        k = line.strip()
                        v = "0"
                    k = k.strip()
                    v = v.strip()

                    for x in ("crashes", "queue"):
                        s = f"{x}Number"

                        if s in k:
                            k = k.replace(s, f"{x} - Number")

                    r[k] = v

                    additional_headers.add(k)
        else:
            if status != "running":
                print("WARNING: no entry for status file",
                      statusf,
                      file=sys.stderr)

        timefile = entry.replace(".results", ".time")

        if os.path.exists(timefile):
            if status != "running":
                with open(timefile) as f:
                    try:
                        l = next(line for line in f.readlines()
                                 if "wall clock" in line)
                        l = l.strip()
                        k = WALL_CLOCK_KEY
                        v = l.split("): ")[1]
                        r[k] = v
                        additional_headers.add(k)
                    except StopIteration:
                        print("[ERROR]", f"'{timefile}'", "is empty")
        else:
            if status != "running":
                print("WARNING: no timefile for", entry, file=sys.stderr)

        addr_count = 0
        tarball = entry.replace(".results", ".tar.xz")

        if os.path.exists(tarball):
            with tarfile.open(tarball) as tf:
                alldone = 0

                for tfinfo in tf:
                    if tfinfo.name.endswith("source_hardcoded_addresses"):
                        contents = tf.extractfile(tfinfo).read()
                        addr_count = len(contents.strip().split(b"\n"))
                        alldone += 1
                    elif tfinfo.name.endswith("bugtypes"):
                        contents = tf.extractfile(tfinfo).read()
                        count = len(contents.strip().split(b"\n"))
                        k = "bugtypes"
                        additional_headers.add(k)
                        r[k] = count
                        alldone += 1
                    elif tfinfo.name.endswith("bugs"):
                        contents = tf.extractfile(tfinfo).read().strip()
                        try:
                            contents = contents.decode("utf-8")
                        except:
                            pass
                        k = "bugs"
                        additional_headers.add(k)
                        r[k] = contents.strip()
                        alldone += 1

                    if alldone == 3:
                        break
                else:
                    print(
                        "WARNING: did not find everything in results tarball",
                        tarball,
                        file=sys.stderr)
        else:
            if status != "running":
                print("WARNING: no results tarball for",
                      entry,
                      file=sys.stderr)

        k = "hardcoded address"
        additional_headers.add(k)
        r[k] = addr_count

        csv_entries.append(r)
        print(".", end="", flush=True)
print()

csv_header_fields = (csv_header_fields[:-1] + list(additional_headers) +
                     [csv_header_fields[-1]])

with open(os.path.abspath(sys.argv[1]), "w", newline='') as f:
    csvw = csv.DictWriter(f, fieldnames=(csv_header_fields))
    csvw.writeheader()

    for r in sorted(csv_entries,
                    key=lambda d: (d['contract'], d['mode'], d['status'])):
        csvw.writerow(r)
        print(r['contract'], "=>", r['mode'], "finding? => ",
              len(r.get("bugs", "")) > 0, r.get(WALL_CLOCK_KEY, "???"))
