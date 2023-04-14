DEFAULT_BUILDS=\
	arbitrary_location_write_simple_fixed-combined-json \
	crypto_roulette-combined-json \
	IndirectEtherTransfers.combined.json \
	keccak.combined.json \
	NoReentrancyDAO.combined.json \
	NoReentrancyDAOLocks.combined.json \
	NoReentrancyDAOOrigin.combined.json \
	noreentrancy_etherstore.combined.json \
	suicide_multitx_infeasible.combined.json \
	good_ac.combined.json \
	NoCodeCallback.combined.json \
	selfcallloop.combined.json


all: print-env $(DEFAULT_BUILDS)

arbitrary_location_write_simple_fixed-combined-json:
	$(MAKE) arbitrary_location_write_simple_fixed.combined.json SOLC_VERSION=0.4.25

crypto_roulette-combined-json:
	$(MAKE) crypto_roulette.combined.json SOLC_VERSION=0.4.19

include ../../sol.Makefile

.PHONY: clean all print-env build-all evm2cpp-all
