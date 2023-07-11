# EF/CF - the Extremely Fast (ethereum smart) Contract Fuzzer

EF/CF is a new approach to smart contract fuzzing: instead of using a new
custom built fuzzer, it repurposes existing fuzzing infrastructure of C/C++
code to smart contracts. Currently, AFL++ is the primarily supported fuzzer,
although there is some very rudimentary support for libfuzzer and honggfuzz as
well.

Why use existing fuzzing infrastructure?

* Speed. We can fuzz faster. We regularly get around 20k execs/sec/core.
* Native code fuzzers are well engineered and optimized.
* Proper coverage-guidance, queue-management, deterministic test case replay,
  etc.

What are some problems that we encounter along the way?

* We need to teach the fuzzer about structure: namely what is a transaction and
  what is the smart contract's ABI. We use a custom mutator for this:
  <a href="https://github.com/uni-due-syssec/efcf-ethmutator">`./src/ethmutator/`</a>
* To increase speed and get useful coverage feedback, we translate EVM bytecode
  to C++ using a custom transpiler
  <a href="https://github.com/uni-due-syssec/efcf-evm2cpp">`./src/evm2cpp/`</a>

This repository the primary entry point for the EF/CF project. It contains all
the relevant code as sub-projects in `./src/` and several convenience scripts for
installation, scripts for launching a fuzzing campaigns and various datasets to
test the fuzzer (and compare against other tools).

* <a href="./src/">`./src/`</a> - contains all source necessary to build and run EF/CF; for
  reproducibility all direct dependencies are added as git submodules.
* <a href="./data/">`./data/`</a> - contains the datasets used during evaluation
* <a href="./scripts/">`./scripts`</a> - contains scripts to run experiments, installation, etc.
* <a href="./docker/">`./docker`</a> - Dockerfile for container-based workflow
    * Standard is Ubuntu, but you can also have a Fedora or Arch Linux
      based container if you like.
    * <a href="./docker/tools">`./docker/tools/`</a> contains dockerfiles for tools that we evaluated EF/CF
      against. We tried our best to use fix the versions we evaluated in our
      paper in the dockerfiles.
* <a href="./EXPERIMENTS.md">`./EXPERIMENTS.md`</a> - contains a guide to
  reproduce the experiments from our paper.
* <a href="./examples/">`./examples`</a> - contains example outputs produced by EF/CF


## The EF/CF Paper

We describe EF/CF's architecture, implementation, and summarize our evaluation
results in our paper: [arxiv.org preprint](https://arxiv.org/abs/2304.06341)

### Citation in Academic Work

When referring to EF/CF in academic work please use the following bibtex entry
for citation:

```bibtex
@InProceedings{efcf2023,
  author       = "Michael Rodler and David Paaßen and Wenting Li and Lukas Bernhard and Thorsten Holz and Ghassan Karame and Lucas Davi",
  title        = "EF/CF: High Performance Smart Contract Fuzzing for Exploit Generation",
  booktitle    = "{IEEE} European Symposium on Security and Privacy ({EuroS\&P})",
  publisher    = "{IEEE}",
  year         = "2023",
}
```


## Quickstart

The recommended way is to run EF/CF as an interactive docker container.

1. Enter the container with a shell
   ```
   docker run --rm -it ghcr.io/uni-due-syssec/efcf-framework
   ```
   or build the container from the cloned repository
   ```
   make gitmodules  # to fetch the git submodules
   make container-enter
   ```
1. Compile and then fuzz a solidity contract until the first crash/bug is
   discovered:
   ```
   efcfuzz --until-crash --out ./baby_bank_results/ --source ./data/examples/baby_bank.sol
   ```
2. Inspect the identified crash
   ```
   cd /tmp/baby_bank_results/
   ./r.sh crashes_min/default_id:000000*
   ```


## Installation / Setup

### Git Submodules

*No git?* if you use a tarball/docker release, ignore this.

Run `git submodule update --init` to fetch the latest submodule commits on already cloned repositories.
Make sure to run this also in `./src/eEVM`.

```
git submodule update --init; cd src/eEVM/; git submodule update --init; cd ../../
```

*Warning:* Running `git clone --recursive $repo` or passing the `--recursive` argument to `git sumbodule (update|init)` will make git recursive into submodules of the AFL++ repository, which are not needed for this project. So to save some space it is better to avoid the recusive submodule checkouts.


### Container

We provide the following convenience make targets for container-based workflows:

```sh
make container-build  # build default efcf container
make container-enter  # enter default efcf container in current working dir
```

If you want to ensure a clean build, you can use the following command 

```sh
make container-build CLEAN_CHECKOUT=1
```

Alternatively the container can be built with the following docker command:

```sh
docker build \
    -f docker/ubuntu.Dockerfile \
    -t efcf:latest \
    .
```

Note that there is also an Archlinux and Fedora based Dockerfile. They should
work as well, but are not as well tested.

For manually distributing a docker image (e.g., if including some local changes), use:

```
make container-release
docker load -i ./efcf*.tar
```

We recommend the following docker options for launching:

* `--security-opt seccomp=unconfined` - better fuzzing perf
* `--net=host` - for easy access to a local ethereum node
* `--tmpfs "/tmp/efcf/":exec,size=6g` - put EF/CF's temporary files onto a ramdisk if possible (less disk wear)
* `--privileged` - to run `afl-system-config` or `efcfuzz --configure-system`
* `-v` - to persist the output data of EF/CF


### VM / Bare-Metal

For VM or bare-metal-based workflows:

```sh
make system-install   # install efcf to current system (requires root or sudo rights)
```

Note that a lot of the scripts work on the relative directory layout anyway, so
this mostly installs dependencies and some tools that are handy to have in your
`PATH`. We have tested running EF/CF on the following Linux distributions:

* Ubuntu Jammy (or later)
* Fedora ($ > 35 $)
* Archlinux

(Distro does not matter that much, we tested LLVM 13 and 14 with 14 being the
preferred choice. LLVM 11 or 12 might also still work, ~~but as always - the newer the
better~~. The important part is that there is a LLVM that is compatible with our fork of AFL++.)


### On Mac OS / M1

We have not tested EF/CF on Mac OS natively. Likely things won't work (e.g., `afl-clang-lto` on Mac OS seems to not work). The best option is to utilize docker.

```sh
# make sure that the submodules are initialized
make gitmodules
# pull the linux/amd64 base image
docker pull ubuntu:jammy --platform linux/amd64
# build the ef/cf image
docker build -t efcf:latest -f docker/ubuntu.Dockerfile --platform linux/amd64 .
# launch the EF/CF container
docker run --tmpfs "/tmp/efcf/":exec,size=8g --platform linux/amd64 --rm -it -v $(pwd):$(pwd) -w $(pwd) efcf:latest 
```

We tested using docker desktop v4.21.1 and basic EF/CF usage works. However, consider the following:
* If you see segfaults while building: try increasing the memory limit of the VM docker uses on Mac OS.
* Try enabling acceleration using rosetta in docker - hopefully this is a bit faster.


### Development Setup

The tools generally do not need to be installed. Install the required
dependencies as in the `system-install.sh` script or as in the Dockerfiles.

For convenience we have some scripts to update your `PATH`:

```sh
# POSIX-like shells (i.e., bash, ...)
source ./scripts/env.sh

# for the fish shell
source ./scripts/env.fish
```

### Etherscan API Key

Some of the scripts require a API key for fetching metadata (e.g., ABI) from
the Etherscan service. If you have an API key you have to set the
`ETHERSCAN_API_KEY` environment variable to pass this to scripts. For
a docker-based workflow you can either launch the docker container with the
`--env` flag or put your API key into the `.etherscan_api_key` file, which will
bake the API key into the docker container.


## Starting EF/CF with the launcher

For convenience, we utilize a wrapper script that takes cares of all the details
for you, when launching the EF/CF fuzzer: `efcfuzz`

You can set many command line options to configure the fuzzer's behavior with
respect to the build and fuzzing process. Take a look at `efcfuzz --help` for a
list of options.

**Examples**

Compile solidity source code to EF/CF native code and start fuzzing for 5
minutes (aka 300 seconds).

```bash
efcfuzz --timeout 300 --source ./data/examples/baby_bank.sol
```

Alternatively, launch with reduced fuzzing output (`--quiet` suppresses the
base fuzzer's output, while `--print-progress` will print a short summary of
the fuzzing progress), and launching the fuzzer on 4 cores.

```bash
efcfuzz --quiet --print-progress --cores 4 --timeout 300 --source ./data/examples/baby_bank.sol
```


Use already compiled bytecode and compile the bytecode to EF/CF native code and start fuzzing.

```bash
# efcfuzz can handle the combined.json output of the solidity compiler
pushd ./data/examples/; make baby_bank.combined.json; popd
efcfuzz --timeout 300 --bin-runtime ./data/examples/baby_bank.combined.json

# but you can also explicitely pass the runtime and deploy bytecode and the ABI
# definition. This is useful if you want to fuzz contracts using other
# compilers (e.g., vyper).
pushd ./data/examples/; make baby_bank; popd
efcfuzz --timeout 300 \
    --bin-runtime ./data/examples/baby_bank.bin-runtime \
    --bin-deploy ./data/examples/baby_bank.bin \
    --abi ./data/examples/baby_bank.abi
```

The wrapper can export a contract's state from a go-ethereum/erigon node and start
fuzzing from there.

```bash
$ efcfuzz --timeout 300 --live-state 0xfffF8D17CB019E0825c478c666B251A7099df3FD
```

Additionally, you can pass `--include-address-deps=y` to recursively search for
addresses of other accounts in the exported contract's storage and also include
those into the state export. However, this does not include other contracts
stored in Solidity `mapping` types. To really export the whole state
recursively pass also the `--include-mapping-deps=y` flag.

But beware, this recursive lookup can lead to long compilation times and poor
fuzzing performance. Especially, frequently used contracts can have a lot of
internal state and using their exported state can make the fuzzing slow. Check
whether the fuzzer can achieve more than 1k execs/sec. If not you should rather
try to craft an artificial and smaller state. Try running a local go-ethereum
node in the `--dev` mode and deploy your contracts there. Then export the live
state from there.

The wrapper caches builds, so a second fuzzing run should launch much faster,
because the initial compilation time is not needed anymore. If you want to only
build and place it into the cache then you can pass the `--build-only` argument.

**Example: Fuzzing with properties**

EF/CF also supports property-based fuzzing using the same property definition
as the [echidna](https://github.com/crytic/echidna#writing-invariants) fuzzer.
Properties (or invariants) are expressed as solidity functions that act as a
bug oracle to the fuzzer. For example, you can add a solidity function:

```solidity
function test_property_balance() public view returns (bool) {
    return total_balance < 1000;
}
```

Which represents the property that the total_balance should always be below
1000. EF/CF will then report a bug if it manages to violate this property using
some transaction sequence, i.e., the oracle returns `false`.

To tell EF/CF that this is a property you need to specify a list of function
signatures in a file, which will be picked up by EF/CF as a list of properties
to check during fuzzing.

The easiest way is to obtain the relevant signatures using the `--hashes` flag
to the solidity compiler, e.g.,

```
solc --hashes ./path/to/your.sol | grep test_property > property_list
```

Now you can launch the fuzzer with:

```
efcfuzz --source ./path/to/your.sol --properties ./property_list -C
```

You can also add `--disable-detectors` to disable the built-in ether-based bug oracles.

You can try the following example for property based fuzzing:

```
efcfuzz \
    --properties ./data/examples/harvey_baz_properties.signatures
    --disable-detectors \
    --until-crash --timeout 120 \
    --source ./data/examples/harvey_baz.sol \
```


**Example: Fuzzing for Events**

EF/CF supports fuzzing for assertion violations that are expressed through
events. Actually, we also support using arbitrary custom events as a bug
oracle. By default, EF/CF will identify a bug if the target contract logged one
of the following events: `AssertionFailed()`, `AssertionFailed(uint256)`,
`AssertionFailed(string)`, and `Panic(uint256)`.

```
efcfuzz --event-assertions \
    --timeout 120 --until-crash \
    --source ./data/properties-assertions-tests/verifyfunwithnumbers.sol
```

You can also specify additional custom event topics/hashes to look out for in a
file with `--event-assertions-list ./path/to/eventslist.txt`. As with the
property list before, you can obtain the format by using `solc --hashes` and
copying the event hashes and names to the event list file.

By default, EF/CF will ignore events that were not issued by the target
contract. If you want to change that use `--event-assertions-target-only=n`.

(Note: you can use `--assertions` to enable both event and solidity assertion
checking)

**Example: Fuzzing for Solidity ^0.8 Assertions**

Currently, we do not support fuzzing for arbitrary assertions in solidity code
for solidity version below 0.8. Previously solidity assertions would simply
trigger a `invalid` opcode, resulting in a quite forceful revert. Solidity
version 0.8 changed the behavior to instead of using the `invalid` opcode to
revert transactions, they now utilize the `revert` mechanism and signal errors
back to the caller. We can utilize this type of error propagation as a bug
oracle in EF/CF. Currently, EF/CF supports checking for the Solidity error type
`Panic(uint256)`. [More information on Solidity
errors.](https://docs.soliditylang.org/en/v0.8.0/control-structures.html?highlight=assert#panic-via-assert-and-error-via-require)

```
efcfuzz --sol-assertions \
    --timeout 120 --until-crash \
    --source ./data/assertions-tests/overflow.sol
```

(Note: you can use `--assertions` to enable both event and solidity assertion
checking)

**System Specs and Configuration**

We recommend allocating 4 to 16 cores and roughly 1 GB of memory per core. You
can utilize the `--configure-system` flag to configure your system for high
speed fuzzing, or configure it yourself. In docker containers you also need to
configure the host for best performance. If it is an uncritical host you can
launch the container as `--privileged` and use
`/usr/local/bin/afl-system-config` to configure the system for high speed
fuzzing (note that this essentially runs the container as root).

```
# configure system
docker run --rm -it --privileged efcf afl-system-config
# run fuzzer (somewhat sandboxed and using a tmpfs for less SSD wear)
docker run --rm -it \
    --security-opt seccomp=unconfined \
    --tmpfs "/tmp/efcf/":exec,size=6g \
    efcf
```


## Running a Fuzzing Experiment

To run the experiment on the `data/tests/` dataset you can use the following
command to build the contracts and their fuzzing harness and then run the
fuzzer with different settings, and multiple repetitions, etc. Because this
would take quite a while we can run those experiments in parallel. We split the
fuzzing experiments into a build step and a fuzz step. The build steps will
build all smart contracts sequentially (the building itself uses multiple cores
though). Then we launch 8 fuzzer instances in the background, which will take
the build artifacts from the build step and start fuzzing runs. The Makefile
will automatically attempt to launch everything in the proper container if
either `docker` or `podman` is available.

```bash
make build-tests
make fuzz-tests CONTAINER_BACKGROUND=1 FUZZER_INSTANCES=8
```

We disable seccomp and network sandboxing when launching the
containers in background. Disabling seccomp sandboxing, improves fuzzing
performance. Using the host network allows EF/CF to access Ethereum nodes in
the local network without further configuration. 

We used the script `./scripts/run-tools-on-dataset.py` to run the other tools
inside docker containers on these datasets, e.g. with these commands for the
multi dataset:
```bash
python3 ./scripts/run-tools-on-dataset.py ./data/multi/
cd ./results/tools-multi/
python3 ../../scripts/get-tools-on-dataset-stats.py
head stats.csv
```

You need to adapt the script to configure the tools and number of runs.

### Setting up a Fuzzing Experiment

Here, we use the `tests` experiment as an example. Simply replace the string
`tests` with the name of the experiment in the following  steps:

1. Gather your dataset in `./data/`, e.g., the `./data/tests` dataset with test
   contracts. For solidity contracts we have a generic `Makefile` to build the
   contracts: `sol.Makefile`. You can reuse this if you wish, see
   `./data/tests/Makefile` for an example. 
2. Create a script to build the build artifacts including any
   pre-processing/scraping step necessary. For example for the `tests` dataset we
   have the `./scripts/build-tests.sh` script. The build artifacts should be
   stored in `./builds/tests/${contract}.build.tar.xz`.
3. Create a script to launch the fuzzing campaign, e.g. for the `tests` dataset
   create a script called `./scripts/fuzz-tests.sh`. Typically you can use the
   common fuzzing campaign function from `./scripts/common.sh`. Take a look at the
   `fuzz-tests.sh` for a template.
4. The results of `fuzz-tests.sh` will be stored in `./results/run-fuzz-tests/`.
5. To summarize the results we provide `./scripts/summarize.py` for the bash
   based launcher scripts and `./scripts/summarize_l.py` for python launcher
   scripts (the `efcfuzz` tool).  
   You might need to adapt these scripts depending on your step 3.
   


### Existing Fuzzing Experiments

#### Benchmarks

* <a href="./data/multi/">`./data/multi`</a> contains the scalability benchmark
  we used to assess how well an analysis tool scales to longer transaction
  sequences. It consists of three types of contracts:
    * `multi_gen_*.sol` - automatically synthesized contracts, which do a bunch
      of `require(input <= MAGIC)` and then set an internal state variable. If
      all state variables are set, then the `selfdestruct` (or echidna oracle)
      can be triggered.
    * `multi_man_complex_*.sol` - manually created variants that work similarly
      to the `multi_gen` type of contracts, but features a bit more tricky
      constraints (e.g., other things than equality and inequality with a magic
      value)
    * `justlen_*.sol` - these are taken from the [echidna-parade example](https://github.com/crytic/echidna-parade/blob/main/examples/justlen.sol)
    * `multi_simple_*.sol` - sanity checks that verify that a fuzzer/tool can
      could in theory find bugs that require 9 or 10 transactions. Here the
      analyzer just needs to call 10 functions in the right order without any
      arguments. This is pretty easy for most analysis tools. 
* <a href="./data/throughput/">`./data/throughput`</a> contains the contracts we
  used for assessing the throughput. This is a selection of contracts with
  varying size. Note that we patched all vulnerabilities in these contracts,
  such that found vulnerabilities do not impact throughput measurements.
* <a href="./data/cov-max-testset">`./data/cov-max-testset`</a> contains the
  contracts we used for comparison of fuzzers based on code coverage.

#### Bug Detection
  
* <a href="./data/ethbmc-vuln">`./data/ethbmc-vuln`</a> list of contracts that
  EthBMC detected as vulnerable.
* <a href="./data/ethbmc-timeouts">`./data/ethbmc-timeouts`</a> list of
  contracts, where EthBMC stopped analysis due to a timeout.
* <a href="./data/reentrancy">`./data/reentrancy`</a> a set of contracts
  vulnerable to reentrancy attacks.
* <a href="./data/sailfish-dao-tp">`./data/sailfish-dao-tp`</a> a set of contracts
  that have been verified to contain a reentrancy bug as part of the
  [sailfish study](https://github.com/ucsb-seclab/sailfish/tree/master/data/ground-truth).
* <a href="./data/sailfish-dao">`./data/sailfish-dao`</a> list of all contracts,
  where
  [sailfish](https://github.com/ucsb-seclab/sailfish/tree/master/data/bugs)
  found a reentrancy bug.
* <a href="./data/sereum">`./data/sereum`</a> a list of contracts
  vulnerable to reentrancy attacks according to [Sereum](https://github.com/uni-due-syssec/sereum-results).
* <a href="./data/smartbugs-curated-accesscontrol">`./data/smartbugs-curated-accesscontrol`</a>
  contracts from the curated smartbugs, classified as "access control" bugs
  ([smartbugs github](https://github.com/smartbugs/smartbugs/tree/master/dataset/access_control))
* <a href="./data/smartbugs-curated-reentrancy">`./data/smartbugs-curated-reentrancy`</a>
  contracts from the curated smartbugs, classified as "reentrancy" bugs
  ([smartbugs github](https://github.com/smartbugs/smartbugs/tree/master/dataset/reentrancy))

#### Tests

The following datasets contain basic synthetic test contracts to test the fuzzer's
capabilities:
  
* <a href="./data/tests">`./data/tests`</a> basic tests gathered from multiple
  sources that check basic capabilities of a fuzzer. All use a selfdestruct
  oracle.
* <a href="./data/tests-not-vuln">`./data/tests-not-vuln`</a> same as tests, but should
  not be detected as vulnerable.
* <a href="./data/properties-tests">`./data/properties-tests`</a> tests for
  property-based fuzzing 
* <a href="./data/assertions-tests">`./data/assertions-tests`</a> tests for
  fuzzing for assertions.


## Fuzzing in more Detail

We utilize wrapper scripts to launch the actual fuzzer (AFL++ in our case).
This is done automatically when using the `efcfuzz` launcher.

```bash
$ cd data/tests
$ make SimpleDAO.evm2cpp
$ cd ../../src/eEVM/
$ env AFL_BENCH_UNTIL_CRASH=1 ./fuzz/launch-aflfuzz.sh SimpleDAO
```

If you have tmux and tmuxp installed then for development and inspection the
interactive version of the script might be useful:

```bash
$ ./fuzz/interactive-aflfuzz.sh -b SimpleDAO
```

This will then compile and fuzz for quite a while. You can then
`cd ./fuzz/out/SimpleDAO*` to view the fuzzing results. Our wrapper scripts do
some extra work on top of launching the `afl-fuzz` program, i.e., mostly
post-processing the results. Additionally it will generated several convenience
scripts to analyze the generated test cases.

* `./a.sh` - Print human-readable form of a test case, wrapper around
  `efuzzcaseanalyzer`.
* `./r.sh` - run a test case with the same settings as when the fuzzer was run.
* `./m.sh` - minimize a testcase with the same settings as when the fuzzer was
  run.
* `./c.sh` - analyze the "chain" of test cases that lead to the given test
  case. Useful for analyzing/optimizng the fuzzer. You can quickly see, which
  test case was produced by which chain of mutations on which queue entries. 
  Requires `fzf`.

There are also some other convenience reports, such as

* `./bugs` and `./bugtypes` that summarize any bugs that were identified.
* `./crashes_min`, which contains minimized crashes of all the `afl-fuzz`
  instances.

**View EVM Basic Block Code Coverage**

```bash
$ cat coverage-percent-all.evmcov
70.73170731707317
```

The script `fuzz/evm-bb-coverage.sh` will compute the basic block coverage
given an AFL output directory. The harness can optionally dump a trace of basic
blocks, which are then compared to a list of basic blocks that is output by
`evm2cpp` (i.e., the `.bb_list` files in `eEVM/contracts/`).

By default we also compute the coverage that our default generic seeds (see
`eEVM/fuzz/generic_seeds` produce:

```bash
$ cat coverage-percent-seeds.evmcov
10.5890
```

The list of covered basic blocks is stored in the file `all.evmcov`.


**View Summary of Generated Testcases**

`efuzzcaseanalyzer` can be used to view/summarize the generated testcases,
e.g.,

```
$ efuzzcaseanalyzer -a ./contract.abi -s ./crashes_min/
Transactions Sequences:
--------------------------------------------------------------
TX [🪙]
    deposit()[🪙];
    withdraw(uint256)[↕️ ↩️ ];
    withdraw(uint256)[];
--------------------------------------------------------------
Number of fuzzcases: 1
Average number of TXs: 3
Number of unique TX sequences: 1
Number of unique TX sequences (consecutive deduplicated): 1
```

The summaries are usually stored in the files `crashes_tx_summary` and
`queue_tx_summary`, but this last one can be a bit verbose.


**Analyze a single crashing testcase**

```
$ ./a.sh default/crashes/id:000000,...
# roughly equivalent to running
$ efuzzcaseanalyzer -a ./contract.abi default/crashes/id:000000,...
Block header:
  number: 0
  difficulty: 0
  gas_limit: 0
  timestamp: 0
  initial_ether: 0

TX with tx_sender: 54 (selector); call_value: 0x0; length: 36; block+=1; #returns=0
  func: withdraw(uint256)
  input: { Uint(80),  }
TX with tx_sender: 238 (selector); call_value: 0x246ddf979; length: 4; block+=1; #returns=0
  func: deposit()
  input: {  }
TX with tx_sender: 153 (selector); call_value: 0x3860e6373; length: 4; block+=1; #returns=0
  func: deposit()
  input: {  }
TX with tx_sender: 166 (selector); call_value: 0x0; length: 36; block+=1; #returns=1
  func: withdraw(uint256)
  input: { Uint(37000000000000000000),  }
  returns:
    return val: 1; allows reenter: 2; data: 0x0000000000000000000000000000000000000000000000000000000000000001
TX with tx_sender: 166 (selector); call_value: 0x0; length: 36; block+=1; #returns=0
  func: withdraw(uint256)
  input: { Uint(37000000000000000000),  }
```

And to get the actual result of the fuzz target, you can execute:

```
$ ./r.sh default/crashes/id:000000,sig:06,src:000000+000010,time:1584,EM-________SAO_______AD
# roughly equivalent to running
$ env EVM_DEBUG_PRINT=1 ./build/fuzz_multitx default/crashes/id:000000,sig:06,src:000000+000010,time:1584,EM-________SAO_______AD

[...]

account 0xc4b803ea8bc30894cc4672a9159ca000d377d9a3 has balance 0x100000000000000000000000000000001bc16d67562e80000( > 0x1000000000000000000000000000000000000000000000000)
Aborted (core dumped)
```

This gives you a lot of verbose output, including some parts of the execution
traces of the contracts and the balance check result that the harness does.


**Minimizing Crashing Inputs**

Crashing inputs often do contain unrelated transactions due to the randomized
testing approach. This can be mitigated by performing a minimization on the
crashing input (i.e., reduce the input as long as it still causes a crash).
If you want to minimize non-crashing inputs, then you can use the `-M` flag to
enable minimization according to coverage as minimization criterion.

The following command will reduce the testcase and overwrite the file:

```
$ efuzzcaseminimizer -oa ./contract.abi ./build/fuzz_multitx ./default/crashes/id:000000,sig:06,src:000000+000010,time:1584,EM-________SAO_______AD

[..]

=== Before minimizing: ===
Block header:
  number: 0
  difficulty: 0
  gas_limit: 0
  timestamp: 0
  initial_ether: 0

TX with tx_sender: 54 (selector); call_value: 0x0; length: 36; block+=1; #returns=0
  func: withdraw(uint256)
  input: { Uint(80),  }
TX with tx_sender: 238 (selector); call_value: 0x246ddf979; length: 4; block+=1; #returns=0
  func: deposit()
  input: {  }
TX with tx_sender: 153 (selector); call_value: 0x3860e6373; length: 4; block+=1; #returns=0
  func: deposit()
  input: {  }
TX with tx_sender: 166 (selector); call_value: 0x0; length: 36; block+=1; #returns=1
  func: withdraw(uint256)
  input: { Uint(37000000000000000000),  }
  returns:
    return val: 1; allows reenter: 2; data: 0x0000000000000000000000000000000000000000000000000000000000000001
TX with tx_sender: 166 (selector); call_value: 0x0; length: 36; block+=1; #returns=0
  func: withdraw(uint256)
  input: { Uint(37000000000000000000),  }

=== After minimizing: ===
Block header:
  number: 0
  difficulty: 0
  gas_limit: 0
  timestamp: 0
  initial_ether: 15133991795

TX with tx_sender: 4 (selector); call_value: 0x246ddf979; length: 4; block+=0; #returns=0
  func: deposit()
  input: {  }
TX with tx_sender: 4 (selector); call_value: 0x0; length: 36; block+=1; #returns=1
  func: withdraw(uint256)
  input: { Uint(37000000000000000000),  }
  returns:
    return val: 1; allows reenter: 2; data: 0x
TX with tx_sender: 0 (selector); call_value: 0x0; length: 36; block+=1; #returns=0
  func: withdraw(uint256)
  input: { Uint(37000000000000000000),  }
```


## Reading the test-case format

The test case format is geared towards fuzzing and is not as straight forward
to read. There are several subtleties you have to be aware of.

* The test case format is considered as a "queue" of transactions that can be
  executed. As soon as any problem is encountered, processing of the test case
  will stop. This includes:
    * When a transaction reverts.
    * Any error is encountered by the harnessing code.
    * Any bug is triggered and detected.
  As a consequence, a printed test case does not necessarily correspond to what
  is executed - there can be transactions at the end that are not executed.
  Check the verbose output and use the minimizer to get rid of those!
* Similarly, there can be too many `returns` or spurious `reenter` flags. Use
  the test case minimizer to get rid of those.
* A contract is only reentered when there is another transaction in the list
  after the transaction that is supposed to do the reentrancy (i.e., there is
  another following entry int the queue).
* Even if the `reenter` flag is set to something, this does not necessarily
  mean that the contract is reentered, just that the harness code will try to
  do it if possible. For example, if the contract does not perform a call the 
  reenter flag is ignored as there is no possibility to reenter. Usually the
  minimizer will remove any spurious reenter flags.

In general many of those issues go away when you use the test case minimizer,
so it is always a good idea to use this one before analyzing generated test
cases.


## Known False Alarms

We observed several types of false alarms that seem to be recurring when
fuzzing contracts with EF/CF.

* Contracts that pay out Ether by design. EF/CF's Ether-gains bug oracle will
  pick up these contracts as vulnerable, although they are operating as
  designed:
    * Gambling contracts: many gambling contracts feature some form of
      randomness, which is already a bad practice in Ethereum. However,
      some gambling contracts are implemented in a way that force you to guess
      e.g., the last two digits of the next blockhash or something similar.
      This can be enabled using a commitment scheme, i.e., the first
      transaction commits the user to a certain value and the second one
      triggers the guess and payout if won. These contracts are usually not
      exploitable in a real blockchain. However, in EF/CF's simulated
      blockchain, the fuzzer can adapt the commitment after the value in the
      second transaction is observed. This fact is important for EF/CF to 
      reach better code coverage. However, it makes it also easy for EF/CF to
      identify a TX sequence that lets the fuzzer deterministically win in the
      gambling contract.
    * Contracts that pay out interest: There are many small contract that allow
      you to invest Ether and then pay out a certain percentage in interest every
      `N` blocks. EF/CF's simulated attacker is capable of waiting for `N` blocks
      and then receives the interest payout, which is again picked up by the 
      Ether-gains bug oracle.
    * Airdrops: some token contracts enable airdrops, i.e., just handing out
      tokens to anyone that requests them until certain limits is reached. For
      example, airdrops are often enabled only for a short period of time.
      If such a contract is deployed within EF/CF, chances are high that the
      time limit is set such that airdrops are still enabled. EF/CF then picks
      up a Ether-gains if the airdropped tokens can be sold again.
* Eager reporting of controllable `DELEGATECALL`: currently we report a
  controllable delegatecall as soon as it is invoked. However, there are
  multiple contracts, which feature functions that intentionally allow the
  caller to perform a delegatecall to an arbitrary address. However, these
  functions will unconditionally revert the transaction immediately after the
  delegatecall. This prevents any state updates or ether transfers from
  persisting. Typically such functions have words like "simulate" in their
  function names and then they are easy to spot.
    * This could be fixed in EF/CF by deferring reporting until the end of the
      execution. However, this complicates the bug oracle quite a bit.
    * Currently there are no plans to fix this.
* Initializer callable: We observed that when fuzzing contracts exported from the
  blockchain, EF/CF is sometimes able to call initializer functions, even
  though the contract was already initialized. Normally, this should trigger a
  revert, but does not do so in EF/CF's EVM environment. Calling the
  initializer again often leads to trivial Ether gains, because e.g., the
  initializer sets an *owner* variable or something similar.
    * We are not yet sure what the root cause of this issue is. However, it is
      typically easily to spot, since the initializer function is typically
      called `initializer`, `init`, or similar.
      
## Common Pitfalls

We did our best to make this somewhat usable, but it is still a research
prototype. Do expect things breaking. Here are some common issues we observed:

* *Q: I get some weird compile error due to a `TOKENPASTE` macro.*  
  A: This often happens when `efcfuzz` guesses the wrong contract name (i.e.,
  it guesses an abstract contract), try passing `--name YourContract` to
  specify the target contract.
