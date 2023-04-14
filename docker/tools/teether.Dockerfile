FROM docker.io/ubuntu:jammy

ARG DEBIAN_FRONTEND=noninteractive
RUN apt-get -y update \
  && apt-get install -y \
    python-is-python3 python3 build-essential git \
    python3-pip wget pypy3 pypy3-dev \
    time \
  && apt-get clean -y \
  && rm -rf /var/lib/apt/lists/*

RUN pypy3 -m pip install pip
RUN pypy3 -m pip install 'git+https://github.com/nescio007/teether.git@ab3b1269342d22e9526941af6816c709d6c401e5' 

ARG PY_VERSION=3.8
ARG MAX_CALLS=32

RUN sed -i "s/max_calls=3/max_calls=$MAX_CALLS/g" /usr/local/lib/pypy$PY_VERSION/dist-packages/teether/exploit.py

ENTRYPOINT ["/usr/bin/time", "-v", "/usr/bin/pypy3", "/usr/local/bin/gen_exploit.py"]
