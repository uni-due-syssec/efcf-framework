FROM docker.io/trailofbits/manticore@sha256:ffa9897f2c5bb8d24fcf27a4ef4bd0405c09f80c762a3abb4103c5b402e610c3

RUN wget -q https://github.com/ethereum/solidity/releases/download/v0.7.6/solc-static-linux \
  && chmod +x solc-static-linux \
  && mv solc-static-linux /usr/bin/solc-0.7.6

RUN apt-get update \
  && apt-get -y upgrade \
  && apt-get install -y time \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/*

ENTRYPOINT ["/usr/bin/time", "-v", "/usr/local/bin/manticore-verifier"]
