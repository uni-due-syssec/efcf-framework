# echidna 1
# FROM docker.io/trailofbits/echidna@sha256:068bb497f0cc064ec59fc4b4f728ea4c9b1b0532bc98d58ea83e60ce15f0c5b6
# echidna 2
FROM docker.io/trailofbits/echidna@sha256:c71e3743530d13f086d6f4bedd12c8f72c9751586910f2d87e87575cab060310

RUN wget -q https://github.com/ethereum/solidity/releases/download/v0.7.6/solc-static-linux \
  && chmod +x solc-static-linux \
  && mv solc-static-linux /usr/bin/solc

RUN apt-get update \
  && apt-get -y upgrade \
  && apt-get install -y \
    time \
    python3-pip \
    git \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/*

RUN pip3 install solc-select
RUN solc-select install 0.7.6 \
  && solc-select use 0.7.6 \
  && solc-select install 0.4.26

#RUN pip3 install 'git+https://github.com/crytic/echidna-parade@afbc4cd7ffcf556a7d18b047a1ba08fad5713ba4'
RUN pip3 install 'git+https://github.com/f0rki/echidna-parade@b298cfef4c54b7cd8d98570a535b6a0dbd53eca7'

ENV PATH=$PATH:/root/.solc-select/artifacts/

ENTRYPOINT ["/usr/bin/time", "-v", "/usr/local/bin/echidna-parade"]
