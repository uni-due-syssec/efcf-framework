FROM docker.io/trailofbits/echidna@sha256:068bb497f0cc064ec59fc4b4f728ea4c9b1b0532bc98d58ea83e60ce15f0c5b6

# RUN wget -q https://github.com/ethereum/solidity/releases/download/v0.7.6/solc-static-linux \
#   && chmod +x solc-static-linux \
#   && mv solc-static-linux /usr/bin/solc

RUN apt-get update \
  && apt-get -y upgrade \
  && apt-get install -y time python3-pip \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/*

RUN pip3 install solc-select \
  && solc-select install 0.7.6 0.5.6 0.5.3 0.4.26 0.4.23
ENV PATH="/root/.solc-select/artifacts/:${PATH}"

ENTRYPOINT ["/usr/bin/time", "-v", "/root/.local/bin/echidna-test"]
