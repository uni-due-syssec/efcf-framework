FROM docker.io/trailofbits/echidna@sha256:c71e3743530d13f086d6f4bedd12c8f72c9751586910f2d87e87575cab060310

# RUN wget -q https://github.com/ethereum/solidity/releases/download/v0.7.6/solc-static-linux \
#   && chmod +x solc-static-linux \
#   && mv solc-static-linux /usr/bin/solc

RUN apt-get update \
  && apt-get -y upgrade \
  && apt-get install -y time python3-pip \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/*

RUN pip3 install solc-select \
  && solc-select install 0.7.6 0.5.6 0.4.26 0.4.23
ENV PATH="/root/.solc-select/artifacts/:${PATH}"

ENTRYPOINT ["/usr/bin/time", "-v", "/root/.local/bin/echidna-test"]
