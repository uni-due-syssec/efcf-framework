# FROM ubuntu:hirsute
FROM ubuntu:jammy

ARG DEBIAN_FRONTEND=noninteractive
RUN apt-get -y update \
  && apt-get install -y \
    python-is-python3 python3 python3-pip python3-virtualenv python3-dev \
    build-essential git \
    python3-pip wget \
    psmisc lsof time \
    wget tar unzip pandoc \
  && apt-get clean -y \
  && rm -rf /var/lib/apt/lists/*

# TODO: solc-select conflicts with the solcx version used with confuzzius
# RUN pip3 install solc-select \
#   && solc-select install 0.7.6 0.5.6 0.4.26 0.4.23
# ENV PATH="/root/.solc-select/artifacts/:${PATH}"
# ENV PATH=$PATH:/usr/local/bin/:/root/.solc-select/artifacts/


ARG Z3_VERSION=4.8.5
RUN pip3 install z3-solver==$Z3_VERSION

WORKDIR /opt
#RUN git clone https://github.com/christoftorres/ConFuzzius.git \
#  && cd ConFuzzius && git checkout 49c7c9edca1e2ffb5915b4113501df92231660a6
RUN git clone -b tweaks3 https://github.com/f0rki/ConFuzzius.git
RUN cd ConFuzzius/fuzzer \
  && pip3 install -r requirements.txt \
  && mv main.py confuzzius.py

# some dirty patching for py3.10 compat...
RUN sed -i 's/from collections /from collections.abc /g' \
  /usr/local/lib/python3.10/dist-packages/eth_account/account.py \
  /usr/local/lib/python3.10/dist-packages/attrdict/mapping.py \
  /usr/local/lib/python3.10/dist-packages/attrdict/mixins.py \
  /usr/local/lib/python3.10/dist-packages/attrdict/merge.py \
  /usr/local/lib/python3.10/dist-packages/attrdict/default.py \
  /usr/local/lib/python3.10/dist-packages/web3/utils/formatters.py

RUN cd /usr/local/lib/python3.10/dist-packages/web3/ \
  && cp datastructures.py datastructures.py.bak \
  && echo "from collections.abc import Hashable, Mapping, MutableMapping, Sequence" > datastructures.py \
  && echo "from collections import OrderedDict" >> datastructures.py \
  && tail -n '+8' datastructures.py.bak >> datastructures.py

RUN sed -i 's/collections.Generator/collections.abc.Generator/g' \
  /usr/local/lib/python3.10/dist-packages/web3/utils/six/six.py

ARG SOLCX_BIN_PATH=/root/.solcx/
RUN python -c 'import solcx; print(list(map(solcx.install_solc, ["0.7.6", "0.5.6", "0.4.26", "0.4.23"])));' \
  && test -d $SOLCX_BIN_PATH \
  && ln -s $SOLCX_BIN_PATH/solc-v0.7.6 /usr/local/solc

# sanity check
RUN cd ConFuzzius/fuzzer && python3 confuzzius.py --help >/dev/null


ENV PYTHONPATH=/opt/ConFuzzius/fuzzer/

WORKDIR /

ENTRYPOINT [ "/usr/bin/time", "-v", "/usr/bin/env", "python", "-c", "from confuzzius import main; main()" ]
