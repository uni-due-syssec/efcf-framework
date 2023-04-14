# Experiments Quickstart

We suggest to have a machine with at least 32 non-hyperthreaded cores available to
reproduce the benchmarks within reasonable time.

## System Preparation

1. Build the docker container:
   ```
   make container-build CLEAN_CHECKOUT=1
   ```
2. Configure the host system for fuzzing:
   ```
   docker run --rm -it --privileged "$(cat ./docker/ubuntu.BUILT)" afl-system-config
   ```

## Scalability Benchmark: Multi, Complex, Justlen

We have four different variants of contracts in this benchmark:

* `./data/multi/multi_gen_*.sol` - synthesized contracts
* `./data/multi/multi_man_complex_*.sol` - manually created contracts
* `./data/multi/justlen*.sol` - adaptions of the `justlen` contracts with
  various array sizes
* `./data/multi/multi_simple_*.sol` - no input constraints, just the
  ordering of transactions. Basically a sanity check that the tool can handle
  multiple TX.

### EF/CF

```sh
make build-multi
make fuzz-multi CONTAINER_BACKGROUND=1 FUZZER_INSTANCES=$(( $(nproc) / 2 ))
```

By default this will run all benchmarks with 10 repetitions and a timeout of 48
hours on half of the cores. This assumes that the system has activated
hyperthreading and only half of the cores are "real" cores. If your system does
not use hyperthreading we suggest to use `$(( $(nproc) - 1 ))` instead. To
reduce the number of repetitions or the timeout one can use a command similar
to the following:

```sh
make fuzz-multi CONTAINER_BACKGROUND=1 FUZZER_INSTANCES=$(( $(nproc) / 2 )) \
    FUZZING_REPETITIONS="3" FUZZING_TIME="$(( 60 * 60 * 12 ))"
```

* `CONTAINER_BACKGROUND=1` launch EF/CF in a docker container in background:
  recommended
* `FUZZER_INSTANCES` number of containers to launch in parallel. Should be
  equal to the number of non-hyperthreaded cores.
* `FUZZING_REPETITIONS` number of repetitions per target, default is 10
* `FUZZING_TIME` timeout for a single fuzzing run in seconds, default is 48h
* `FUZZ_MODES` is a space-separated list of fuzzing configurations of EF/CF,
  e.g., `"2AT noabi"`. Default is only `"2AT"`. Available modes are:
    * `2AT` default, AFL++ with cmplog in `2AT` setting and ethmutator with
      compare tracing
    * `aonly` AFL++ with cmplog in `2AT` without ethmutator
    * `monly` AFL++ but using *only* ethmutator for mutations
    * `noabi` like default, but do not load ABI in ethmutator
    * `interp` like default, but run in interpreter; requires special build
    * `none` like default, but disable AFL++ cmplog

To get a summary of the results as CSV file, run the following command:

```
python scripts/summarize.py ./results/fuzz-multi.csv ./results/run-fuzz-multi/
```


### Running Other Tools

We use a different script to manage running other tools on the benchmarks. This
script will attempt to fully utilize all available non-hyperthreaded cores on
the machine running the experiments. By default, it assigns one core to a
docker container and will launch as many containers as possible. Periodically
this script will check whether it can schedule a new container once a core
becomes free due to another container exiting.
Make sure that you have built the EF/CF container with `make container-build`
before running these commands.

1. Edit the launcher script to adapt the tools, timeout and number of
   repetitions. We suggest to reduce the number of repetitions or the timeout
   drastically. Many tools will hit the timeout of 48 hours, making the
   experiment take *very very* long (i.e., weeks).
   ```
   $EDITOR ./scripts/run-tools-on-dataset.py
   ```
   We suggest to adapt the timeout to something reasonable depending on the
   available computing resources.
2. Launch the benchmarks. This script runs in the foreground and will produce
   quite a bit of console output. You can monitor the spawned containers using
   `docker ps`. Since it is running in the foreground this should
   run in a tmux or screen session.
   ```
   python3 ./scripts/run-tools-on-dataset.py ./data/multi/
   ```
3. Inspect results and generate CSV
   ```
   cd ./results/tools-multi/
   python3 ../../scripts/get-tools-on-dataset-stats.py
   head stats.csv  # inspect the results
   cp stats.csv ../tools-multi.csv
   ```

### Results / Analysis / Plots

We have a number of different plots (beyond those in the paper), which are
generated using a *Jupyter* notebook using a combination of pandas/matplotlib/seaborn.

```
cd ./results/
# clear previously saved plots (can cause permission denied errors)
rm *.pdf *.svg *.png || true
docker run -it --rm -p 8888:8888 -v "${PWD}":/home/jovyan/work jupyter/datascience-notebook
```

1. Click on the link from the `jupyter` terminal output, that contains the
   special access token.
2. Visit http://127.0.0.1:8888/lab/tree/work/multi_analysis.ipynb to open the
   notebook.
3. Adapt the paths to the CSV files to point to the newly generated data;
   comment out the data points that you do not want to see in the plots.
4. Re-generate all plots by clicking `Run` / `Run All Cells`.


## Throughput Benchmark

Selected number of contracts to benchmark the throughput of EF/CF in various
modes and the throughput of other analysis tools.

### EF/CF

```sh
make build-throughput
make fuzz-throughput CONTAINER_BACKGROUND=1 FUZZER_INSTANCES=$(( $(nproc) / 2 ))
```

The commands work similar to the previously described benchmark. However, here
we have a fixed timeout of 10 minutes per fuzzer and configuration with 20
repetitions. As such, this benchmark finishes in roughly 13 hours on a
single core or 25 minutes on 32 cores.

To get a summary of the results as CSV file, run the following command:

```
python scripts/summarize.py ./results/fuzz-throughput.csv ./results/run-fuzz-throughput/
```

### Other Tools

1. Edit the launcher script to adapt the tools, timeout and number of
   repetitions.  
   ```
   $EDITOR ./scripts/run-tools-on-dataset.py
   ```
   Adapt the configuration to the throughput experiment:
   * Set 20 repetitions for `echidna2` and `confuzzius` in the `TOOLS`
     dictionary in this script.
   * Set `GLOBAL_TIMEOUT=60 * 10`
2. Launch the tools on the throughput dataset.
   ```
   python3 ./scripts/run-tools-on-dataset.py ./data/throughput/
   ```
3. Generate CSV
   ```
   python3 scripts/summarize-throughput.py ./results/tools-throughput.summary.csv
   ```
   
### Results / Analysis / Plots

Again launch jupyter:

```
cd ./results/
# clear previously saved plots (can cause permission denied errors)
rm *.pdf *.svg *.png || true
docker run -it --rm -p 8888:8888 -v "${PWD}":/home/jovyan/work jupyter/datascience-notebook
```

1. Click on the link from the `jupyter` terminal output, that contains the
   special access token.
2. Visit http://127.0.0.1:8888/lab/tree/work/throughput_analysis.ipynb to open the
   notebook.
3. Adapt the paths to the CSV files to point to the newly generated data;
   comment out the data points that you do not want to see in the plots.
4. Re-generate all plots/tables by clicking `Run` / `Run All Cells`.


## Code Coverage Comparison

TODO


## Live-State Analysis

The following experiments export contracts from the live Ethereum mainnet
blockchain and use this state as a starting point for fuzzing.

### Preparation

**Ethereum Full Node:** The following experiments require access to the `debug`
API of a fully synched archive-mode go-ethereum or erigon node. If you have ssh
access to a server running such a node, you can utilize the following command
to forward the port.

```
ssh -N -L 8545:127.0.0.1:8545 user@hostname
```

Depending on the synchronization state of the Ethereum node, the experiments
might have slightly different outcomes or fail completely (e.g., because a
contract selfdestructed or because parts of the Ethereum state are not
available on the node).

**Etherscan API:** We utilize the [etherscan.io](etherscan.io/) service to
search for contract ABIs when given only a contract address. Register with the
service to obtain an API key. Put the key into the file `.etherscan_api_key`
and rebuild the docker image.


### Experiments

The following experiments are available and utilize datasets from previous work
on access control and reentrancy bug detection. There is no separate build
phase.

* `make fuzz-ethbmc-vuln` - contracts considered to be vulnerable by EthBMC
    * requires a fully synched archive node (uses quite old blockchain state
      for export)
* `make fuzz-ethbmc-timeouts` - contracts, where EthBMC timeouted
    * requires a fully synched archive node (uses quite old blockchain state
      for export)
* `make fuzz-sailfish-dao-tp` - a small number of contracts verified by the
  sailfish authors to be vulnerable
  ([source](https://github.com/ucsb-seclab/sailfish/blob/master/data/ground-truth/sailfish.dao.tp)).
* `make fuzz-sailfish-dao` - the full list of contracts that sailfish
  considered vulnerable
  ([source](https://github.com/ucsb-seclab/sailfish/blob/master/data/bugs/sailfish.dao)).
* `make fuzz-sereum` - list of contracts considered to be vulnerable to
  reentrancy according to [Sereum](https://github.com/uni-due-syssec/sereum-results/tree/v2).
* `make fuzz-eeg-re` - list of contracts considered to be vulnerable in the
  ["Ever Evolving Game" paper](https://yangzhemin.github.io/papers/evolving-game-security20.pdf)
  ([artifacts](https://drive.google.com/file/d/1xLssDxYWyKFCwS5HUrQaSex0uwJRSvDi/view)).
* *Serif* - the four contracts of the Serif datasets can be found in other
  directories, see <a href="./data/serif/README.md">the serif README.md</a> for
  details.

The results can be turned into a CSV files by running the `summarize_l.py`
script, which takes a path to the new CSV file as a first argument, and the
directory of the fuzzing results as the second argument, e.g.,

```
python ./scripts/summarize_l.py ./results/ethbmc-vuln.summary.csv ./results/run-fuzz-ethbmc-vuln/
```

For the other datasets, the command must be adapted accordingly.
 
### Results / Analysis

Again launch jupyter:

```
cd ./results/
# clear previously saved plots (can cause permission denied errors)
rm *.pdf *.svg *.png || true
docker run -it --rm -p 8888:8888 -v "${PWD}":/home/jovyan/work jupyter/datascience-notebook
```

1. Click on the link from the `jupyter` terminal output, that contains the
   special access token.
2. Visit http://127.0.0.1:8888/lab/tree/work/livestate_analysis.ipynb to open the
   notebook.
3. Adapt the paths to the CSV files to point to the newly generated data, if
   needed.
4. Re-generate all plots/tables by clicking `Run` / `Run All Cells`.



## Basic Tests

We have multiple datasets consisting of mostly synthetic contracts to test the
EF/CF fuzzer:

* `./data/tests/` - basic tests that exercise the fuzzers capability to solve
  constraints and identify Ether gain / selfdestruct vulnerabilities.
    * Requires running `make build-tests` before.
* `./data/tests-not-vuln/` - same as tests, but contains contracts that are not
  exploitable, but could be picked as exploitable due to over-approximation in
  the analysis tool.
    * Requires running `make build-tests-not-vuln` before.
* `./data/assertions-tests/` - tests the custom assertion based bug oracles
  built into EF/CF
* `./data/properties-tests/` - tests the echidna-style property-based fuzzing
  capabilities of EF/CF
* `./data/tests-multi-abi` - some basic tests that exercise the multi-target
  multi-abi fuzzing capabilities of EF/CF.
    * This dataset is not yet automated and requires special handling, please
      see [the README](./data/tests-multi-abi/README.md).

Generally the datasets can be fuzzed like the *multi* dataset above:

```sh
make fuzz-tests CONTAINER_BACKGROUND=1 FUZZER_INSTANCES=$(( $(nproc) / 2 ))
```
