FROM docker.io/ubuntu:hirsute

ARG DEBIAN_FRONTEND=noninteractive
RUN apt-get -y update \
  && apt-get install -y \
    python-is-python3 python3 git \
    build-essential cmake meson ninja-build automake autoconf texinfo flex bison pkg-config \
    python3-pip wget \
    time \
    clang-12 llvm-12 cmake libleveldb-dev libgmp-dev \
    libboost-dev \
  && apt-get clean -y \
  && rm -rf /var/lib/apt/lists/*

RUN pip3 install solc-select
RUN solc-select install 0.7.6 \
  && solc-select install 0.4.21

WORKDIR /opt/
RUN git clone --recursive https://github.com/f0rki/sFuzz \
  && cd sFuzz/ \
  && mkdir build \
  && cd build && cmake -G Ninja .. \
  && cd fuzzer/ \
  && ninja
