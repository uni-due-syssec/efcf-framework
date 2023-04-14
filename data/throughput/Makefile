DEFAULT_BUILDS=\
	crowdsale.combined.json \
	multi10.combined.json \
	SpankchainLedgerChannel-combined-json \
	IMBTC-combined-json \
	PackSale-combined-json \
	CryptoBets-combined-json

all: print-env $(DEFAULT_BUILDS)

include ../../sol.Makefile


SpankchainLedgerChannel-combined-json: SpankchainLedgerChannel.sol
	$(MAKE) SpankchainLedgerChannel.combined.json SOLC_VERSION=0.4.23 SOLC_ARGS="--optimize --optimize-runs 1"

IMBTC-combined-json: IMBTC.sol
	$(MAKE) IMBTC.combined.json SOLC_VERSION=0.5.3

PackSale-combined-json: PackSale.sol
	$(MAKE) PackSale.combined.json SOLC_VERSION=0.4.25
	
CryptoBets-combined-json: CryptoBets.sol
	$(MAKE) CryptoBets.combined.json SOLC_VERSION=0.4.25

.PHONY: clean all print-env build-all evm2cpp-all
