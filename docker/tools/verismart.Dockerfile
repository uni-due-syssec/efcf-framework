FROM ubuntu:jammy

# Install some basic pre-requisites
RUN apt-get -qq update \
  && apt-get install -q -y \
    sudo wget git \
    build-essential g++ gcc m4 make pkg-config libgmp3-dev unzip cmake \
    opam \
    python3 python3-pip \
    python2 python2-dev \
    time \
  && apt-get clean -q -y \
  && rm -rf /var/lib/apt/lists/*

RUN pip3 install solc-select
RUN solc-select install 0.7.6 \
  && solc-select use 0.7.6 \
  && solc-select install 0.4.26
ENV PATH=$PATH:/root/.solc-select/artifacts/


ARG VERISMART_URL=https://github.com/kupl/VeriSmart-public.git
ARG VERISMART_COMMIT=99be7ba88b61994f1ed4c0d3a8e6a6db0f790431

WORKDIR /build
RUN git clone $VERISMART_URL ./verismart

WORKDIR /build/verismart
RUN git config --global advice.detachedHead false \
  && git checkout $VERISMART_COMMIT

RUN opam init -y --disable-sandboxing \
  && eval $(opam env) \
  && opam update \
  && opam install -y \
    conf-m4.1 ocamlfind ocamlbuild num yojson batteries ocamlgraph zarith
# Make sure that ocamlbuild and such exists in the path
RUN echo 'eval $(opam env)' >> $HOME/.bashrc

WORKDIR /build
ARG Z3_URL=https://github.com/Z3Prover/z3/releases/download/z3-4.7.1/z3-4.7.1.tar.gz
RUN wget -q -O src.tar.gz $Z3_URL \
  && tar -xvzf src.tar.gz \
  && cd z3* \
  && eval $(opam env) \
  && python3 scripts/mk_make.py --ml \
  && cd build \
  && make -j $(nproc) \
  && make install \
  && echo "[z3] cleanup" \
  && cd /build \
  && rm -rf z3*


WORKDIR /build/verismart
RUN chmod +x build && eval $(opam env) && ./build && ./main.native --help >/dev/null
RUN ln -s $(realpath ./main.native) /usr/local/bin/verismart

ENTRYPOINT [ "/usr/bin/time", "-v", "/build/verismart/main.native" ]
