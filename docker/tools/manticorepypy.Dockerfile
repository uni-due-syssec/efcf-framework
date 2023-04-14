FROM ubuntu:jammy

LABEL name=Manticore
LABEL src="https://github.com/trailofbits/manticore"

ENV LANG C.UTF-8

ARG DEBIAN_FRONTEND=noninteractive
RUN apt-get update \
  && apt-get -y upgrade \
  && apt-get install -y \
    time \
    pypy3 pypy3-dev python3-pip \
    build-essential git wget curl \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/*


ENV PATH=$PATH:/usr/local/bin/

RUN test -e /usr/bin/python && rm /usr/bin/python || true
RUN test -e /usr/bin/python3 && rm /usr/bin/python3 || true
RUN ln -s /usr/bin/pypy3 /usr/bin/python \ 
  && ln -s /usr/bin/pypy3 /usr/bin/python3

RUN wget -q -O /usr/bin/solc https://github.com/ethereum/solidity/releases/download/v0.4.26/solc-static-linux \
  && wget -q -O /usr/bin/solc-0.7.6 https://github.com/ethereum/solidity/releases/download/v0.7.6/solc-static-linux \
  && chmod +x /usr/bin/solc* /usr/bin/solc

RUN pypy3 -m pip install -U pip

ARG COMMIT=52007a8fa59e2234b4e69ff9167e8c35916aff6b
RUN git clone https://github.com/trailofbits/manticore.git \
  && cd manticore && git checkout $COMMIT \
  && sed -i 's/default=True/default=False/' ./manticore/utils/helpers.py
RUN cd manticore && pypy3 -m pip install .

ENTRYPOINT ["/usr/bin/time", "-v", "pypy3", "/usr/local/bin/manticore-verifier"]
