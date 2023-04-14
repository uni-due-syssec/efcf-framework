SOLC_VERSION ?= 0.7.6
SOLC_ARGS ?=
CONTRACT_FILE ?= whatever.sol

PROJECT_ROOT:=$(shell dirname $(realpath $(lastword $(MAKEFILE_LIST))))/
EEVM_DIR:=$(PROJECT_ROOT)/src/eEVM

include $(PROJECT_ROOT)/container.Makefile

print-env: container-env
	@echo
	@echo "PROJECT_ROOT    = $(PROJECT_ROOT)"
	@echo "SOLC_VERSION    = $(SOLC_VERSION)"
	@echo "CONTRACT_FILE   = $(CONTRACT_FILE)"
	@echo "EEVM_DIR        = $(EEVM_DIR)"

ifeq ($(SOLC_VERSION), )
SOLC_BIN=solc
else
SOLC_BIN=solc-$(SOLC_VERSION)
endif

ifeq ($(CONTAINER_RUNTIME), )
%.combined.json: %.sol
	-$(RM) combined.json
	$(SOLC_BIN) $(SOLC_ARGS) --combined-json abi,bin,bin-runtime,srcmap,srcmap-runtime -o . --overwrite $< > $@.out
else
%.combined.json: %.sol $(CONTAINER_STAMP)
	-$(RM) combined.json
	$(CONTAINER_RUNTIME) run $(CONTAINER_RUN_FLAGS) $(shell cat $(CONTAINER_STAMP)) \
		bash -c \
		"set -e; $(SOLC_BIN) $(SOLC_ARGS) --combined-json abi,bin,bin-runtime,srcmap,srcmap-runtime -o . --overwrite $< > $@.out"
endif
	@(test -e combined.json && mv -f combined.json $@) || (cat "$@.out" | jq > "$@")
	@test -s $@ || (echo "empty file" $@ && rm $@ && false)

ifeq ($(CONTAINER_RUNTIME), )
build-all:
	solc-$(SOLC_VERSION) $(SOLC_ARGS)  --bin --bin-runtime --abi --hashes -o . --overwrite $(CONTRACT_FILE)
else
build-all: $(CONTAINER_STAMP)
	$(CONTAINER_RUNTIME) run $(CONTAINER_RUN_FLAGS) $(shell cat $(CONTAINER_STAMP)) \
		solc-$(SOLC_VERSION) $(SOLC_ARGS)  --bin --bin-runtime --abi --hashes -o . --overwrite $(CONTRACT_FILE)
endif

clean:
	-$(RM) *.combined.json *.bin *.bin-runtime *.sourcemap *_storage.json *.abi *.signatures *.out

%: %.sol
	$(MAKE) CONTRACT_FILE=$< build-all

%.bin: %
%.bin-runtime: %


ALL_COMBINED_JSON=$(wildcard *.combined.json)

evm2cpp-all: $(ALL_COMBINED_JSON)
	for cj in $^; do echo "$$cj"; evm2cpp -e $(EEVM_DIR) "$$(basename "$$cj" | cut -d '.' -f 1)" "$$cj"; done


ifneq ($(OVERRIDE_EVM2CPP), 1)
ifeq ($(CONTAINER_RUNTIME), )
%.evm2cpp: %.combined.json
	evm2cpp -e $(EEVM_DIR) "$(shell basename "$<" | cut -d '.' -f 1)" $<
else
%.evm2cpp: %.combined.json $(CONTAINER_STAMP)
	$(CONTAINER_RUNTIME) \
		run $(CONTAINER_RUN_FLAGS) \
		-v "$(EEVM_DIR):$(EEVM_DIR):Z" \
		$(shell cat $(CONTAINER_STAMP)) \
		evm2cpp -e $(EEVM_DIR) "$(shell basename "$<" | cut -d '.' -f 1)" $<
endif
endif


%.ethbmc.yml: %.combined.json
	$(PROJECT_ROOT)/scripts/make_ethbmc_yml.py $< > $@
	@test -s $@ || (echo "empty file" $@ && rm $@ && false)


.PHONY: clean all print-env build-all evm2cpp-all
