import json
import dateutil.parser
import glob
import subprocess
import re

stats_file = "stats.csv"


def detectBug(tool, filepath):
    cmd = ''
    res = ''

    if tool.startswith("confuzzius"):
        # -----------------------------------------------------
        #       !!! Unprotected selfdestruct detected !!!
        # -----------------------------------------------------
        cmd = f'grep -o "\w* detected" {filepath} | sort -u'
        filter = lambda s: s.split()[0]

    elif tool.startswith("maian"):
        # [-] Suicidal vulnerability found!
        cmd = f'grep -o "\w* vulnerability found!" {filepath}  | sort -u'
        filter = lambda s: s.split()[0]

    elif tool.startswith("echidna"):
        # echidna_oracle: failed!💥
        cmd = f'grep -o "\w*: failed!" {filepath} | sort -u'
        filter = lambda s: s.split()[0][:-1]

    elif tool.startswith("ethbmc"):
        # =========================================================
        # Found attack, can trigger contract suicide
        # =========================================================
        cmd = f'grep -o "Found attack, can .*$" {filepath} | sort -u'
        filter = lambda s: s[len("Found attack, can "):]

    elif tool.startswith("manticore"):
        # +----------------+------------+
        # | Property Named |   Status   |
        # +----------------+------------+
        # | echidna_oracle | failed (0) |
        # +----------------+------------+
        cmd = f'grep -o "\w* | failed" {filepath} | sort -u'
        filter = lambda s: s.split()[0]

    elif tool.startswith("teether"):
        cmd = f'grep -o "eth\.sendTransaction" {filepath} | wc -l'
        filter = lambda s: "None" if int(s.strip()) == 0 else s.strip()

    elif tool.startswith("verismart"):
        cmd = f'grep -o \'\\[KA\\] line.\\+;\' {filepath} | sort -u'
        filter = lambda s: s.strip().replace("[KA]", "").replace(";", "").replace(",", ":")

    elif tool.startswith("smartian"):
        cmd = f"grep -o 'found SuicidalContract' {filepath} | sort -u"
        filter = lambda s: s.strip()

    else:
        print("Not analysed tool", tool)
        return 'N/A'

    res = subprocess.run(cmd, shell=True, stdout=subprocess.PIPE).stdout

    if len(res) > 0:
        bugs = []

        for bug in str(res, 'utf-8').strip().split('\n'):
            bugs.append(filter(bug))

        return ':'.join(bugs)

    return 'None'


if __name__ == "__main__":

    with open(stats_file, 'w') as f:
        print("tool,contract,txlength,trial,runtime,bugfound", file=f)

    results = []

    for filepath in glob.iglob(r'*.status.json'):
        fields = filepath.split(".")

        if len(fields) == 5:
            fields = filepath.split(".", 3)[:-1]
        elif len(fields) == 6:
            # tool with special mode such as c4 or thorough
            fields = filepath.split(".", 4)[:-1]
        elif len(fields) == 7:
            # tool with double-special mode such as c4 or thorough
            # e.g., echidnaparade.justlen128.p1.c4.2
            fields = list(filepath.split(".", 5)[:-1])
            fields = fields[:2] + [(fields[2] + "_" + fields[3]) ,fields[4]]
        else:
            raise Exception(f"can't handle {fields!r}")
        print(fields)
        tool = fields[0].replace("prime", "")
        m = re.search('(.*)_([0-9]+)', fields[1])

        if m is None:
            if fields[1].strip().startswith("justlen"):
                contract = "justlen"
                txLength = str(int(fields[1].replace("justlen", "").strip()))
            else:
                contract = fields[1]
                txLength = ""
        else:
            contract = m.group(1)
            txLength = m.group(2)

        if len(fields) == 4:
            method = fields
            tool += '.' + fields[-2]
        runNumber = fields[-1]
        with open(filepath, 'r') as f:
            statusJson = json.load(f)
            runTime = (dateutil.parser.isoparse(statusJson["FinishedAt"]) -
                       dateutil.parser.isoparse(
                           statusJson["StartedAt"])).total_seconds()

        bugs = detectBug(tool, filepath[:-len('.status.json')] + '.log')

        results.append(','.join(
            [tool, contract, txLength,
             str(runNumber),
             str(runTime), bugs]))

    with open(stats_file, 'a') as f:
        print('\n'.join(sorted(results)), file=f)

    print(f"Saved analysis result to file '{stats_file}'")
