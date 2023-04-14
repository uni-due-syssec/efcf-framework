SOLC_VERSION ?= 0.4.26
DEFAULT_BUILDS=$(patsubst %.sol,%.combined.json,$(wildcard *.sol))

all: print-env $(DEFAULT_BUILDS)

include ../../sol.Makefile

.PHONY: clean all print-env build-all evm2cpp-all
