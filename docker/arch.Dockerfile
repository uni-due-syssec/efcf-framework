FROM docker.io/archlinux:base-devel

RUN pacman -Syu --noconfirm --needed \
  && pacman-db-upgrade \
  && pacman -Syu --noconfirm --needed \
      git wget curl unzip bash zsh grml-zsh-config jq \
      python python-pip \
      clang llvm lld libc++ \
      meson cmake ninja \
      libunwind binutils \
      rust rust-analyzer \
      time \
      ripgrep \
      gnuplot \
      go-ethereum \
      mimalloc \
  && pacman -Scc --noconfirm

RUN mkdir -p /data /scripts /src/
COPY data /data/
COPY src /src/
COPY scripts /scripts/
RUN chmod +x /scripts/*

# we install all kinds of solidity versions
RUN pip install -U solc-select
RUN solc-select install all
ENV PATH="/root/.solc-select/artifacts/:${PATH}"

RUN cargo install --force ethabi-cli

ARG INSTALL_DIR=/efcf/

WORKDIR $INSTALL_DIR/src/
COPY src/AFLplusplus/ AFLplusplus
VOLUME $INSTALL_DIR/ccache
env CCACHE_DIR=$INSTALL_DIR/ccache
ENV PATH="/usr/lib/ccache/:${PATH}"
WORKDIR $INSTALL_DIR/src/AFLplusplus
ARG NO_PYTHON=1
# ARG NO_SPLICING=1
ARG NO_NYX=1
RUN make clean; make source-only && make install
env PATH=$PATH:/usr/local/bin/

WORKDIR $INSTALL_DIR/src/
COPY src/evm2cpp/ evm2cpp
WORKDIR $INSTALL_DIR/src/evm2cpp
RUN make clean; make && make install; \
  rm -rf target/release/{deps,build} target/debug || true

WORKDIR $INSTALL_DIR/src/
COPY src/ethmutator/ ethmutator
WORKDIR $INSTALL_DIR/src/ethmutator
RUN make clean; make && make install; \
  rm -rf target/release/{deps,build} target/debug || true

WORKDIR $INSTALL_DIR/src/
COPY src/launcher/ launcher
WORKDIR $INSTALL_DIR/src/launcher
RUN pip install .
# share installed solc between solc-select and solcx
RUN mkdir -p /root/.solcx \
    && mkdir -p /usr/local/lib/python3.9/dist-packages/solcx/ \
    && ln -s /root/.solcx /usr/local/lib/python3.9/dist-packages/solcx/bin; \
    set -e; for solc in /root/.solc-select/artifacts/solc-*; do \
      ln -s "$(realpath "$solc")" \
        "/root/.solcx/solc-v$(basename $solc | cut -c 6-)"; \
    done; \
    python -c 'import solcx; print(solcx.get_installed_solc_versions())'

WORKDIR $INSTALL_DIR
COPY .git .git
COPY data data
COPY src/eEVM src/eEVM
COPY scripts scripts
COPY Makefile Makefile
COPY sol.Makefile sol.Makefile
COPY container.Makefile container.Makefile
RUN chmod +x scripts/* ; \
    echo "$EFCF_VERSION-$(git rev-parse HEAD)" > VERSION;

WORKDIR $INSTALL_DIR/src/
RUN tar cJf eEVM.orig.tar.xz ./eEVM/

ARG REMOVE_GIT_DIR=0
WORKDIR $INSTALL_DIR/
RUN if test "$REMOVE_GIT_DIR" -eq 1; then rm -rf .git; fi

# make sure to configure the host s.t., this doesn't matter..
ENV AFL_SKIP_CPUFREQ=1
ENV AFL_I_DONT_CARE_ABOUT_MISSING_CRASHES=1
# it seems if we run multiple containers in parallel, then we need to set this
# or otherwise all AFL instances will bind to the first CPU core.
ENV AFL_NO_AFFINITY=1
ENV FUZZ_USE_SHM=0
ENV FUZZ_USE_TMPFS=0

VOLUME $INSTALL_DIR/out
VOLUME $INSTALL_DIR/results

WORKDIR $INSTALL_DIR
ENV EFCF_INSTALL_DIR=$INSTALL_DIR

ENV RUST_BACKTRACE=full

ARG ETHERSCAN_API_KEY=
ENV ETHERSCAN_API_KEY=$ETHERSCAN_API_KEY

CMD [ "zsh" ]
