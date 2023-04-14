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

import sys
import tempfile
from pathlib import Path

from .state import (dump_state_json, dump_state_msgpack, load_state_json,
                    load_state_msgpack)


def print_usage_and_exit():
    print("usage:\n",
          "\t" + sys.argv[0],
          "<path_to_in_state>",
          "<path_to_out_state>",
          "\n\t(You can use '-' as an alias for stdin/stdout)",
          file=sys.stderr)
    sys.exit(1)


def main():
    if len(sys.argv) not in (2, 3) or "--help" in sys.argv or "-h" in sys.argv:
        print_usage_and_exit()

    if len(sys.argv) == 2:
        outpath = "-"
    else:
        outpath = Path(sys.argv[2])

    inpath = sys.argv[1]
    _tmpfile = None
    if inpath == "-":
        _tmpfile = tempfile.NamedTemporaryFile(suffix=".state.msgpack")
        _tmpfile.write(sys.stdin.buffer.read())
        _tmpfile.flush()
        inpath = Path(_tmpfile.name)
    else:
        inpath = Path(sys.argv[1])

    in_is_mpack = True
    if inpath.suffix.replace(".", "") in ('msgpack', 'mpack'):
        in_is_mpack = True
    if inpath.suffix.replace(".", "") == "json":
        in_is_mpack = False

    if inpath.expanduser().absolute().exists():
        pass
    else:
        print("ERROR: Input file does not exist",
              inpath,
              "\n",
              file=sys.stderr)
        print_usage_and_exit()

    state = None
    if in_is_mpack:
        state = load_state_msgpack(inpath)
    else:
        state = load_state_json(inpath)

    out_is_mpack = True
    if outpath == "-" or outpath.name == "-":
        out_is_mpack = False
        # linux only? ¯\_(ツ)_/¯
        outpath = Path("/proc/self/fd/1")
    else:
        if outpath.suffix.replace(".", "") == "json":
            out_is_mpack = False
        elif outpath.suffix.replace(".", "") in ("msgpack", "mpack"):
            out_is_mpack = True

    if out_is_mpack:
        dump_state_msgpack(state, outpath)
    else:
        dump_state_json(state, outpath)

    if _tmpfile:
        _tmpfile.close()
    sys.exit(0)


if __name__ == "__main__":
    main()
