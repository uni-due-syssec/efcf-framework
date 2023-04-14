ARG UBUNTU_VERSION=jammy
FROM docker.io/ubuntu:$UBUNTU_VERSION

ARG EFCF_VERSION=1

ARG LLVM_VERSION=14
ARG GCC_VERSION=11

ARG DEBIAN_FRONTEND=noninteractive
RUN apt-get update -q \
  && echo full-upgrade \
  && apt-get full-upgrade --no-install-recommends -q -y \
  && echo install \
  && apt-get install --no-install-recommends -q -y \
    git wget curl unzip subversion \
    bash zsh less time jq ripgrep \
    build-essential cmake meson ninja-build automake autoconf texinfo flex bison pkg-config \
    ccache \
    binutils-multiarch binutils-multiarch-dev \
    libfontconfig1-dev libgraphite2-dev libharfbuzz-dev libicu-dev libssl-dev zlib1g-dev \
    libtool-bin python3-dev libglib2.0-dev libpixman-1-dev clang python3-setuptools llvm \
    python3 python3-dev python3-pip python-is-python3 \
    gcc-$GCC_VERSION-multilib gcc-$GCC_VERSION-plugin-dev \
    libunwind-$LLVM_VERSION-dev libunwind-$LLVM_VERSION \
    llvm-$LLVM_VERSION clang-$LLVM_VERSION \
    llvm-$LLVM_VERSION-dev \
    llvm-$LLVM_VERSION-tools lld-$LLVM_VERSION clang-format-$LLVM_VERSION \
    libc++1-$LLVM_VERSION libc++-$LLVM_VERSION-dev \
    libc++abi1-$LLVM_VERSION libc++abi-$LLVM_VERSION-dev \
    nodejs npm \
  && echo "install gnuplot" \
  && apt-get install --no-install-recommends -q -y gnuplot-nox \
  && apt-get clean -y \
  && rm -rf /var/lib/apt/lists/* \
  && update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-$GCC_VERSION 100 \
      --slave /usr/bin/g++ g++ /usr/bin/g++-10 \
  && update-alternatives --install /usr/bin/cpp cpp-10 /usr/bin/cpp-$GCC_VERSION 100 \
  && update-alternatives \
    --install /usr/bin/clang   clang     /usr/bin/clang-$LLVM_VERSION 700 \
    --slave /usr/bin/clang++   clang++   "/usr/bin/clang++-$LLVM_VERSION" \
    --slave /usr/bin/clang-cpp clang-cpp "/usr/bin/clang-cpp-$LLVM_VERSION" \
  && update-alternatives \
    --install /usr/bin/llvm-config     llvm-config      /usr/bin/llvm-config-$LLVM_VERSION  200 \
    --slave /usr/bin/llvm-ar           llvm-ar          /usr/bin/llvm-ar-$LLVM_VERSION \
    --slave /usr/bin/llvm-as           llvm-as          /usr/bin/llvm-as-$LLVM_VERSION \
    --slave /usr/bin/llvm-bcanalyzer   llvm-bcanalyzer  /usr/bin/llvm-bcanalyzer-$LLVM_VERSION \
    --slave /usr/bin/llvm-cov          llvm-cov         /usr/bin/llvm-cov-$LLVM_VERSION \
    --slave /usr/bin/llvm-diff         llvm-diff        /usr/bin/llvm-diff-$LLVM_VERSION \
    --slave /usr/bin/llvm-dis          llvm-dis         /usr/bin/llvm-dis-$LLVM_VERSION \
    --slave /usr/bin/llvm-dwarfdump    llvm-dwarfdump   /usr/bin/llvm-dwarfdump-$LLVM_VERSION \
    --slave /usr/bin/llvm-extract      llvm-extract     /usr/bin/llvm-extract-$LLVM_VERSION \
    --slave /usr/bin/llvm-link         llvm-link        /usr/bin/llvm-link-$LLVM_VERSION \
    --slave /usr/bin/llvm-mc           llvm-mc          /usr/bin/llvm-mc-$LLVM_VERSION \
    --slave /usr/bin/llvm-mcmarkup     llvm-mcmarkup    /usr/bin/llvm-mcmarkup-$LLVM_VERSION \
    --slave /usr/bin/llvm-nm           llvm-nm          /usr/bin/llvm-nm-$LLVM_VERSION \
    --slave /usr/bin/llvm-objdump      llvm-objdump     /usr/bin/llvm-objdump-$LLVM_VERSION \
    --slave /usr/bin/llvm-ranlib       llvm-ranlib      /usr/bin/llvm-ranlib-$LLVM_VERSION \
    --slave /usr/bin/llvm-readobj      llvm-readobj     /usr/bin/llvm-readobj-$LLVM_VERSION \
    --slave /usr/bin/llvm-rtdyld       llvm-rtdyld      /usr/bin/llvm-rtdyld-$LLVM_VERSION \
    --slave /usr/bin/llvm-size         llvm-size        /usr/bin/llvm-size-$LLVM_VERSION \
    --slave /usr/bin/llvm-stress       llvm-stress      /usr/bin/llvm-stress-$LLVM_VERSION \
    --slave /usr/bin/llvm-symbolizer   llvm-symbolizer  /usr/bin/llvm-symbolizer-$LLVM_VERSION \
    --slave /usr/bin/llvm-tblgen       llvm-tblgen      /usr/bin/llvm-tblgen-$LLVM_VERSION \
    --slave /usr/bin/scan-build        scan-build       /usr/bin/scan-build-$LLVM_VERSION


ENV RUSTUP_HOME=/usr/local/rustup
ENV CARGO_HOME=/usr/local/cargo
ARG RUST_VERSION="1.59.0"
# we use rustup instead to fetch the rust version we used
RUN wget -q -O /tmp/rustup.sh https://sh.rustup.rs \
  && sh /tmp/rustup.sh -y -t "$RUST_VERSION" --default-toolchain "$RUST_VERSION" --profile minimal \
  && rm /tmp/rustup.sh
ENV PATH=$PATH:$CARGO_HOME/bin/

# we install all kinds of solidity versions
RUN pip3 install -U solc-select
# in case you are missing a version ->
# RUN solc-select install all
# but to keep image size somewhat reasonable we install only the most common ones in our dataset
RUN solc-select install 0.4.10 0.4.11 0.4.12 0.4.13 0.4.14 0.4.15 0.4.16 0.4.17 0.4.18 0.4.19 \
                        0.4.20 0.4.21 0.4.22 0.4.23 0.4.24 0.4.25 0.4.26 \
                        0.5.0 0.5.1 0.5.2 0.5.3 0.5.4 0.5.6 0.5.7 0.5.8 0.5.9 0.5.10 \
                        0.7.6 \
                        0.8.13
# incompatible with newest solc-select...
ARG SOLC_SELECT_PATH_DIR=/root/.solc-select/PATH/
RUN set -e; mkdir -p "$SOLC_SELECT_PATH_DIR"; for solc in /root/.solc-select/artifacts/solc-* /root/.solc-select/artifacts/solc-*/solc-*; do \
      echo "$solc"; if ! test -d "$solc"; then ln -s "$(realpath "$solc")" \
        "$SOLC_SELECT_PATH_DIR/$(basename $solc)"; fi \
    done;
ENV PATH="$SOLC_SELECT_PATH_DIR:$PATH"

RUN cargo install --force ethabi-cli

ARG GETH_URL=https://gethstore.blob.core.windows.net/builds/geth-linux-amd64-1.10.16-20356e57.tar.gz
WORKDIR /opt/
RUN wget -q -O - $GETH_URL \
  | tar xz \
  && mv ./*/geth /usr/local/bin/ \
  && chmod +x /usr/local/bin/geth

ARG MIMALLOC_VERSION=v2.0.5
ARG MIMALLOC_REPO=https://github.com/microsoft/mimalloc.git
WORKDIR /opt/
RUN git clone -b $MIMALLOC_VERSION $MIMALLOC_REPO mimalloc \
  && cd mimalloc \
  && mkdir -p out/release \
  && cd out/release \
  && cmake -G Ninja ../../ \
  && ninja \
  && ninja install \
  && cd /opt/ \
  && rm -rf mimalloc

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
ENV NO_ARCH_OPT=1
ENV IS_DOCKER=1
ARG NO_PYTHON=1
ARG NO_NYX=1
ARG NO_CORESIGHT=1
# ARG NO_SPLICING=1
RUN make clean; make source-only && make install && afl-clang-lto --version >/dev/null
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
    set -e; for solc in /root/.solc-select/artifacts/solc-* /root/.solc-select/artifacts/solc-*/solc-*; do \
      echo "$solc"; if ! test -d "$solc"; then ln -s "$(realpath "$solc")" \
        "/root/.solcx/solc-v$(basename $solc | cut -c 6-)"; fi \
    done; \
    python -c 'import solcx; print(solcx.get_installed_solc_versions())'
ENV PATH="$PATH:/root/.solcx/"

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
