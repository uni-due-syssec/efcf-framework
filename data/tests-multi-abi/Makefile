OVERRIDE_EVM2CPP=1
DEFAULT_BUILDS=\
			   simplemultiabi.combined.json \
			   simplemultiabi_re.combined.json


all: print-env $(DEFAULT_BUILDS)


include ../../sol.Makefile

ifeq ($(CONTAINER_RUNTIME), )
%.evm2cpp: %.combined.json
	evm2cpp -e $(EEVM_DIR) --translate-all $<
else
%.evm2cpp: %.combined.json $(CONTAINER_STAMP)
	$(CONTAINER_RUNTIME) \
		run $(CONTAINER_RUN_FLAGS) \
		-v "$(EEVM_DIR):$(EEVM_DIR):Z" \
		$(shell cat $(CONTAINER_STAMP)) \
		evm2cpp -e $(EEVM_DIR) --translate-all $<
endif

ifeq ($(CONTAINER_RUNTIME), )
%.state: %.combined.json %.evm2cpp
	env EEVM_DIR=$(EEVM_DIR) python3 ./make_state_load.py $<
	env EEVM_DIR=$(EEVM_DIR) python3 ./abi_concat.py $<
else
%.state: %.combined.json %.evm2cpp $(CONTAINER_STAMP)
	$(CONTAINER_RUNTIME) \
		run $(CONTAINER_RUN_FLAGS) \
		-v "$(EEVM_DIR):$(EEVM_DIR):Z" \
		$(shell cat $(CONTAINER_STAMP)) \
		env EEVM_DIR=$(EEVM_DIR) python3 ./make_state_load.py $< && \
		env EEVM_DIR=$(EEVM_DIR) python3 ./abi_concat.py $<
endif

.PHONY: clean all print-env build-all evm2cpp-all
