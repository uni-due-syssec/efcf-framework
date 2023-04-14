FROM ubuntu:hirsute

ARG DEBIAN_FRONTEND=noninteractive
RUN apt-get -y update \
  && apt-get install -y \
    python-is-python3 python3 python3-pip python3-virtualenv python3-dev \
    build-essential git \
    pypy3 pypy3-dev \
    python3-pip wget \
    psmisc lsof time \
    wget tar unzip pandoc \
  && apt-get clean -y \
  && rm -rf /var/lib/apt/lists/*

# Install solidity
RUN pip3 install solc-select
RUN solc-select install 0.7.6 \
  && solc-select install 0.4.26

ENV PATH=$PATH:/usr/local/bin/:/root/.solc-select/artifacts/

WORKDIR /opt
#RUN git clone https://github.com/christoftorres/ConFuzzius.git \
#  && cd ConFuzzius && git checkout 49c7c9edca1e2ffb5915b4113501df92231660a6
RUN git clone -b tweaks https://github.com/f0rki/ConFuzzius.git
RUN cd ConFuzzius/fuzzer \
  && pypy3 -m pip install -r requirements.txt \
  && pypy3 -m pip install z3-solver \
  && mv main.py confuzzius.py

RUN ln -s /root/.solc-select/artifacts /usr/local/lib/pypy3.6/dist-packages/solcx/bin
RUN mkdir -p /usr/local/lib/python3.9/dist-packages/solcx/ \
  && ln -s /root/.solc-select/artifacts /usr/local/lib/python3.9/dist-packages/solcx/bin
#RUN python -c 'import solcx; solcx.install_solc("0.7.6"); solcx.install_solc("0.4.26");'
RUN pypy3 -c 'import solcx; solcx.install_solc("0.7.6"); solcx.install_solc("0.4.26");'

ENV PYTHONPATH=/opt/ConFuzzius/fuzzer/

WORKDIR /

# interestingly pypy does not seem to help wrt to tx/s
ENTRYPOINT [ "/usr/bin/time", "-v", "/usr/bin/env", "pypy3", "-c", "from confuzzius import main; main()" ]
#ENTRYPOINT [ "/usr/bin/time", "-v", "/usr/bin/env", "python", "-c", "from confuzzius import main; main()" ]
