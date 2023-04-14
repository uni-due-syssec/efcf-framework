FROM registry.fedoraproject.org/fedora:35

#RUN dnf groupinstall "Development Tools" "Development Libraries" \
RUN dnf install -y \
      git wget curl unzip bash jq python python-pip make \
      gcc clang llvm lld \
      meson cmake ninja-build binutils \
      ccache \
      libunwind libunwind-devel \
      mimalloc mimalloc-devel \
      rust cargo \
      time ripgrep gnuplot-minimal \
      zsh

# we install all kinds of solidity versions
RUN pip install -U solc-select
# in case you are missing a version ->
# RUN solc-select install all
# but to keep image size somewhat reasonable we install only the most common ones in our dataset
RUN solc-select install 0.4.10 0.4.11 0.4.12 0.4.13 0.4.14 0.4.15 0.4.16 0.4.17 0.4.18 0.4.19 \
                        0.4.20 0.4.21 0.4.22 0.4.23 0.4.24 0.4.25 0.4.26 \
                        0.5.0 0.5.1 0.5.2 0.5.3 0.5.4 0.5.6 0.5.7 0.5.8 0.5.9 0.5.10 \
                        0.7.6 \
                        0.8.13
ENV PATH="/root/.solc-select/artifacts/:${PATH}"

RUN cargo install --force ethabi-cli

ARG GETH_URL=https://gethstore.blob.core.windows.net/builds/geth-linux-amd64-1.10.16-20356e57.tar.gz
WORKDIR /opt/
RUN wget -q -O - $GETH_URL \
  | tar xz - \
  && mv ./*/geth /usr/local/bin/ \
  && chmod +x /usr/local/bin/geth

# install a nice zsh config for interactive container use
ARG ZSH_CONFIG_URL=https://git.grml.org/f/grml-etc-core/etc/zsh/zshrc
RUN mkdir -p /etc/zsh && wget -qO /etc/zsh/zshrc $ZSH_CONFIG_URL

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
