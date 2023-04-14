#!/usr/bin/env python

import string
import csv
import datetime as dt
import re
import sys
import os
from pathlib import Path


def runtime_str_to_delta(runtime):
    try:
        t = dt.datetime.strptime(runtime, "%H:%M:%S.%f")
    except ValueError:
        try:
            t = dt.datetime.strptime(runtime, "%M:%S.%f")
        except ValueError:
            t = dt.datetime.strptime(runtime, "%S.%f")
    delta = dt.timedelta(hours=t.hour, minutes=t.minute, seconds=t.second)
    return delta


ECHIDNA_LINE_RE = re.compile(r'echidna.+: fuzzing \(([0-9]+)/[0-9]+\)')

csv_header_fields = [
    "tool", "contract", "run", "throughput", "metric", "runtime"
]

with open(os.path.abspath(sys.argv[1]), "w", newline='') as f:
    csvw = csv.DictWriter(f, fieldnames=(csv_header_fields))
    csvw.writeheader()

    for cflog in Path("./results/tools-throughput/").glob("confuzzius.*.log"):
        components = str(cflog.name).split(".")
        contract = components[1]
        run = int(components[2].strip())
        runtime = None
        num = None
        with cflog.open() as f:
            for line in f.readlines():
                line = line.strip()
                if "Transactions per second" in line:
                    num = line.split(":")[-1].strip()
                    num = int(num)
                if "Elapsed" in line and "time" in line:
                    runtime = line.split(" ")[-1]
                    delta = runtime_str_to_delta(runtime)
                    runtime_secs = delta.total_seconds()
        if num is None or runtime_secs is None:
            print("incomplete => confuzzius on", contract, "run", run, "num", num, 'runtime', runtime_secs)
        r = {
            'tool': "confuzzius",
            'metric': 'tx / sec',
            'contract': contract,
            'run': run,
            'throughput': num,
            'runtime': runtime_secs,
        }
        csvw.writerow(r)

    for cflog in Path("./results/tools-throughput/").glob(
            "echidnaprime.*.log"):
        components = str(cflog.name).split(".")
        contract = components[1]
        run = int(components[2].strip())
        num = None
        runtime_secs = None
        with cflog.open() as f:
            for line in f.readlines():
                line = line.strip(string.whitespace)
                m = ECHIDNA_LINE_RE.search(line)
                if m and num is None:
                    num = m.groups()[0]
                    num = int(num)
                if "Elapsed" in line and "time" in line:
                    runtime = line.split(" ")[-1]
                    delta = runtime_str_to_delta(runtime)
                    runtime_secs = delta.total_seconds()
        if num is None or runtime_secs is None:
            print("incomplete => echidna on", contract, "run", run, "num", num, 'runtime', runtime_secs)
        r = {
            'tool': "echidna",
            'metric': 'testcase / sec',
            'contract': contract,
            'run': run,
            'throughput': num / runtime_secs if num else None,
            'runtime': runtime_secs,
        }
        csvw.writerow(r)
    
    for cflog in Path("./results/tools-throughput/").glob(
            "echidna2.*.log"):
        components = str(cflog.name).split(".")
        contract = components[1]
        run = int(components[2].strip())
        num = None
        runtime_secs = None
        with cflog.open() as f:
            for line in f.readlines():
                line = line.strip(string.whitespace)
                m = ECHIDNA_LINE_RE.search(line)
                if m and num is None:
                    num = m.groups()[0]
                    num = int(num)
                if "Elapsed" in line and "time" in line:
                    runtime = line.split(" ")[-1]
                    delta = runtime_str_to_delta(runtime)
                    runtime_secs = delta.total_seconds()
        if num is None or runtime_secs is None:
            print("incomplete => echidna2 on", contract, "run", run, "num", num, 'runtime', runtime_secs)
        r = {
            'tool': "echidna2",
            'metric': 'testcase / sec',
            'contract': contract,
            'run': run,
            'throughput': num / runtime_secs if num else None,
            'runtime': runtime_secs,
        }
        csvw.writerow(r)
