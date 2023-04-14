#FROM ubuntu:jammy
FROM ubuntu:18.04
ARG UBUNTU_VERSION=18.04

ARG DOTNET_VERSION=5.0
ENV DOTNET_CLI_TELEMETRY_OPTOUT=1

# Install some basic pre-requisites
RUN apt-get -qq update \
  && apt-get install -q -y \
    sudo wget git \
    build-essential g++ gcc m4 make pkg-config libgmp3-dev unzip cmake \
    python3 python3-pip \
    python python-dev \
    libssl-dev \
    time \
    wget apt-transport-https git unzip \
    build-essential libtool libtool-bin \
    automake autoconf bison flex sudo \
    curl software-properties-common \
    python3 python3-pip libssl-dev pkg-config \
    libsqlite3-0 libsqlite3-dev apt-utils locales \
    libleveldb-dev python3-setuptools \
    python3-dev pandoc python3-venv \
    libgmp-dev libbz2-dev libreadline-dev libsecp256k1-dev locales-all \
  && apt-get clean -q -y \
  && rm -rf /var/lib/apt/lists/*

RUN wget -q https://packages.microsoft.com/config/ubuntu/$UBUNTU_VERSION/packages-microsoft-prod.deb -O packages-microsoft-prod.deb \
  && dpkg -i packages-microsoft-prod.deb \
  && apt-get -q update \
  && apt-get -q -yy install dotnet-sdk-$DOTNET_VERSION \
  && rm -f packages-microsoft-prod.deb \
  && apt-get clean -q -y \
  && rm -rf /var/lib/apt/lists/*

RUN pip3 install solc-select
RUN solc-select install 0.7.6 \
  && solc-select use 0.7.6 \
  && solc-select install 0.4.26
ENV PATH=$PATH:/root/.solc-select/artifacts/


#ARG SMARTIAN_URL=https://github.com/SoftSec-KAIST/Smartian.git
#ARG SMARTIAN_COMMIT=45430325557db85f32d034b6aca70a4d9cc27d66
ARG SMARTIAN_URL=https://github.com/f0rki/Smartian.git
ARG SMARTIAN_COMMIT=a1bd96e0be9b27cfd19a71aff8ff3860b3c90ee8

WORKDIR /build
RUN git clone $SMARTIAN_URL ./smartian
WORKDIR /build/smartian
RUN git config --global advice.detachedHead false \
  && git checkout $SMARTIAN_COMMIT \
  && git submodule update --init --recursive \
  && git show --oneline -s


WORKDIR /tmp

WORKDIR /build/smartian
RUN make
#RUN mkdir -p build && dotnet build -c Release -o ./build/

ENTRYPOINT [ "/usr/bin/time", "-v", "dotnet", "/build/smartian/build/Smartian.dll" ]
