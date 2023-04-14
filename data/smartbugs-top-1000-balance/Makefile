SOURCES := $(wildcard *.sol)
OBJECTS := $(patsubst %.combined.json, %.sol, $(SOURCES))

all: $(OBJECTS)

include ../../sol.Makefile


ifeq ($(CONTAINER_RUNTIME), )
%.evm2cpp: %.combined.json
	evm2cpp -e $(EEVM_DIR) "$(shell cat $$(basename -s ".combined.json" $<).meta.json.xz | xz -d | jq -r '.[0].ContractName')" $<

else
%.evm2cpp: %.combined.json $(CONTAINER_STAMP)
	$(CONTAINER_RUNTIME) \
		run $(CONTAINER_RUN_FLAGS) \
		-v "$(EEVM_DIR):$(EEVM_DIR):Z" \
		$(shell cat $(CONTAINER_STAMP)) \
		make $<
endif
