# Docker file for https://github.com/eth-sri/ilf
# FROM ubuntu:18.04
FROM ubuntu:jammy

ARG DEBIAN_FRONTEND=noninteractive
RUN apt-get -y update \
    && apt-get -y install \
    wget \
    python3 \
    python3-pip \
    libssl-dev \
    curl \
    git \
    autoconf automake build-essential libffi-dev libtool pkg-config python3-dev \
    time \
  && apt-get clean -y \
  && rm -rf /var/lib/apt/lists/*

# install nodejs truffle web3 ganache-cli
RUN curl -sL https://deb.nodesource.com/setup_12.x | bash - \
  && apt-get -y update \
  && apt-get -y install nodejs \
  && apt-get clean -y \
  && rm -rf /var/lib/apt/lists/*

RUN npm -g config set user root \
  && npm install -g truffle web3 ganache-cli

# install solc
#RUN wget https://github.com/ethereum/solidity/releases/download/v0.4.25/solc-static-linux
#RUN mv solc-static-linux /usr/bin/solc
#RUN chmod +x /usr/bin/solc
RUN pip3 install solc-select \
  && solc-select install 0.7.6 0.5.6 0.4.26 0.4.23
ENV PATH="/root/.solc-select/artifacts/:${PATH}"

# install go
RUN wget https://dl.google.com/go/go1.10.4.linux-amd64.tar.gz \
  && tar -xvf go1.10.4.linux-amd64.tar.gz \
  && mv go /usr/lib/go-1.10
RUN mkdir /go
ENV GOPATH=/go
ENV GOROOT=/usr/lib/go-1.10
ENV PATH=$PATH:$GOPATH/bin
ENV PATH=$PATH:$GOROOT/bin

# install z3
# RUN git checkout z3-4.8.6
RUN git clone --depth=1 -b z3-4.8.6 https://github.com/Z3Prover/z3.git \
  && cd /z3 \
  && python3 scripts/mk_make.py --python \
  && cd build \
  && make -j$(nproc) \
  && make install


ARG ILF_REPO=https://github.com/eth-sri/ilf.git
ARG ILF_COMMIT=d855cda12e6f1ff36936ed98dae95326bc4f3154

# copy ilf
# ADD ./ /go/src/ilf/
RUN git clone $ILF_REPO /go/src/ilf \
  && cd /go/src/ilf \
  && git checkout $ILF_COMMIT

# install go-ethereum
RUN mkdir -p /go/src/github.com/ethereum/
WORKDIR /go/src/github.com/ethereum/
RUN git clone https://github.com/ethereum/go-ethereum.git \
  && cd /go/src/github.com/ethereum/go-ethereum \
  && git checkout 86be91b3e2dff5df28ee53c59df1ecfe9f97e007 \
  && git apply /go/src/ilf/script/patch.geth
# RUN go get github.com/ethereum/go-ethereum
# WORKDIR /go/src/github.com/ethereum/go-ethereum
# RUN git checkout 86be91b3e2dff5df28ee53c59df1ecfe9f97e007
# RUN git apply /go/src/ilf/script/patch.geth

WORKDIR /go/src/ilf
# install python dependencies

RUN pip3 install -r requirements.txt --no-cache-dir
RUN go build -o execution.so -buildmode=c-shared export/execution.go

#ENTRYPOINT [ "/bin/bash" ]
ENTRYPOINT [ "/usr/bin/time", "-v", "python3", "-m", "ilf" ]
