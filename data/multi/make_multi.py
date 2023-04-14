#!/usr/bin/env python

# what?

import sys
import random
import enum
import itertools

# random, but deterministic seed, s.t., shorter generated multiN.sol contracts
# are basically a prefix of longer ones
random.seed(0x32a84cb965a18f5c)


class Constraint(enum.IntEnum):
    EQUALS_CONSTANT = enum.auto()
    LESS_THAN_CONSTANT = enum.auto()
    GREATER_THAN_CONSTANT = enum.auto()
    EQUALS_OTHER_ARG = enum.auto()
    LESS_THAN_OTHER_ARG = enum.auto()
    GREATER_THAN_OTHER_ARG = enum.auto()
    FIRST_CALL = enum.auto()


constraints = itertools.cycle([
    Constraint.EQUALS_CONSTANT,
    Constraint.LESS_THAN_CONSTANT,
    Constraint.FIRST_CALL,
    Constraint.LESS_THAN_OTHER_ARG,
    Constraint.GREATER_THAN_CONSTANT,
    Constraint.EQUALS_OTHER_ARG,
    Constraint.GREATER_THAN_OTHER_ARG,
])

constants = itertools.cycle([
    1,
    42,
    (1 << 256) - 101,
    10000,
    1 << 128,
    0x4b026586da41ca949205b2cee33db59ded7590b8cdf7cc1ffcb831a30669,
])

contract_tmpl = """
pragma solidity ^0.7;

contract multi_gen_{last_state} {{
    {state_vars}

    constructor() payable {{ }}

    {functions}

    function echidna_oracle() public view returns (bool) {{
        return (!state{last_state});
    }}

    function ether_oracle() public {{
        require(state{last_state});
        selfdestruct(msg.sender);
    }}
}}
"""

function_tmpl = """
    function f{num}({args}) public {{
        {constraints}
        state{num} = true;
    }}
"""


def synthesize_multi(function_count):
    functions = []
    state_vars = []
    last_state = function_count
    for fnum in range(1, function_count + 1):
        print("synthesizing function", fnum)
        state_vars.append(f"bool state{fnum} = false;")
        arg_count = random.randint(1, 6)
        args = ", ".join(f"uint arg{i}" for i in range(arg_count))
        constraint_list = [f"require(state{fnum - 1});" if fnum > 1 else ""]
        a = 0
        while a < arg_count:
            arg = f"arg{a}"
            c = next(constraints)

            print("  constraint:", c, "for", arg)

            if c in (Constraint.EQUALS_CONSTANT, Constraint.LESS_THAN_CONSTANT,
                     Constraint.GREATER_THAN_CONSTANT):
                if c == Constraint.EQUALS_CONSTANT:
                    op = "=="
                elif c == Constraint.LESS_THAN_CONSTANT:
                    op = "<="
                elif c == Constraint.GREATER_THAN_CONSTANT:
                    op = ">="
                else:
                    raise NotImplementedError(
                        f"can't handle op for constraint type {c}")

                cs = f"require({arg} {op} {next(constants)});"

            elif c in (Constraint.EQUALS_OTHER_ARG,
                       Constraint.LESS_THAN_OTHER_ARG,
                       Constraint.GREATER_THAN_OTHER_ARG):

                if c == Constraint.EQUALS_OTHER_ARG:
                    op = "=="
                elif c == Constraint.LESS_THAN_OTHER_ARG:
                    op = "<="
                elif c == Constraint.GREATER_THAN_OTHER_ARG:
                    op = ">="
                else:
                    raise NotImplementedError(
                        f"can't handle op for constraint type {c}")

                if arg_count == 1:
                    # fallback to a constant when there is only one arg
                    other_arg = next(constants)
                elif a == arg_count - 1:
                    other_arg = f"arg{a - 1}"
                else:
                    other_arg = f"arg{a + 1}"

                cs = f"require({arg} {op} {other_arg});"

            elif c == Constraint.FIRST_CALL:
                cs = f"require(!state{fnum});"
                a -= 1

            else:

                raise NotImplementedError(f"cannot handle constraint type {c}")

            constraint_list.append(cs)
            a += 1

        func = function_tmpl.format(num=fnum,
                                    args=args,
                                    constraints="\n".join(constraint_list))
        functions.append(func)

    return contract_tmpl.format(last_state=last_state,
                                functions="\n".join(functions),
                                state_vars="\n".join(state_vars))


if len(sys.argv) == 1:
    print("usage:", sys.argv[0], "<function_count>",
          "[function_count_range_end]")
    sys.exit(-1)

start = int(sys.argv[1])

if len(sys.argv) >= 3:
    end = int(sys.argv[2]) + 1
else:
    end = start + 1

for function_count in range(start, end):
    print("[+] synthesizing multi test contract with", function_count, "functions")
    with open(f"./multi_gen_{function_count}.sol", "w") as f:
        f.write(synthesize_multi(function_count))
