FROM docker.io/rust as rust_builder

ARG COMMIT=60d1b58d9df78e696f6c8e7b982ca9b271348518

WORKDIR /opt/
RUN git clone https://github.com/RUB-SysSec/EthBMC.git
WORKDIR /opt/EthBMC

RUN git checkout $COMMIT 
ARG USE_RUST_VERSION='nightly-2021-11-01'
RUN rustup install $USE_RUST_VERSION && rustup default $USE_RUST_VERSION
RUN cargo build --release

FROM docker.io/ubuntu:jammy

COPY --from=rust_builder /opt/EthBMC /opt/EthBMC

ARG DEBIAN_FRONTEND=noninteractive
RUN apt-get -y update \
  && apt-get -y install boolector z3 build-essential wget autoconf gperf libgmp3-dev time \
  && apt-get clean -y \
  && rm -rf /var/lib/apt/lists/*

ARG YICES2_URL=https://github.com/SRI-CSL/yices2/archive/refs/tags/2021-02-19.tar.gz
WORKDIR /opt/yices2/
RUN wget -q -O /tmp/yices.tar.gz "$YICES2_URL" \
  && tar --strip-components=1 -xf /tmp/yices.tar.gz \
  && rm /tmp/yices.tar.gz \
  && autoconf && ./configure && make && make install


ARG GETH_URL=https://gethstore.blob.core.windows.net/builds/geth-alltools-linux-amd64-1.10.4-aa637fd3.tar.gz
WORKDIR /usr/local/bin/
RUN wget -q -O /tmp/geth.tar.gz "$GETH_URL" \
  && tar --strip-components=1 -xf /tmp/geth.tar.gz \
  && rm /tmp/geth.tar.gz

ENV PATH=$PATH:/opt/EthBMC/target/release/

ENTRYPOINT ["/usr/bin/time", "-v", "/opt/EthBMC/target/release/ethbmc"]
