FROM docker.io/ubuntu:jammy

ARG DEBIAN_FRONTEND=noninteractive
RUN apt-get -y update \
  && apt-get install -y \
    python-is-python3 python3 build-essential git \
    pypy3 pypy3-dev \
    python3-pip wget \
    psmisc lsof time \
  && apt-get clean -y \
  && rm -rf /var/lib/apt/lists/*

RUN pip3 install solc-select
RUN solc-select install 0.7.6

RUN pypy3 -m pip install z3-solver web3 "rlp==0.6.0" pysha3

ARG GETH_URL=https://gethstore.blob.core.windows.net/builds/geth-alltools-linux-amd64-1.10.4-aa637fd3.tar.gz
WORKDIR /usr/local/bin/
RUN wget -q -O /tmp/geth.tar.gz "$GETH_URL" \
  && tar --strip-components=1 -xf /tmp/geth.tar.gz \
  && rm /tmp/geth.tar.gz

ENV PATH=$PATH:/usr/local/bin/

WORKDIR /opt/
#RUN git clone https://github.com/ivicanikolicsg/MAIAN.git \
#  && cd MAIAN \
#  && git fetch origin refs/pull/24/head:pull_24 \
#  && git checkout pull_24
RUN git clone https://github.com/f0rki/MAIAN.git

WORKDIR /
ENTRYPOINT ["/usr/bin/time", "-v", "/usr/bin/pypy3", "/opt/MAIAN/tool/maian.py"]
