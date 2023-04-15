include container.Makefile

help:
	@echo "We provide the following convenience make targets"
	@echo "for container-based workflows:"
	@echo "    make container-build  # build default efcf container"
	@echo "    make container-enter  # enter default efcf container in current working dir"
	@echo ""
	@echo "for VM/baremetal-based workflows:"
	@echo "    make system-install   # install efcf to current system (require root or sudo)"
	@echo ""


system-install: gitmodules
	$(GIT_PROJECT_ROOT)/scripts/system-install.sh

bump:
	./scripts/bump-all-src-commits.sh

ifeq ($(CONTAINER_RUNTIME), )
run-%: ./scripts/%.sh
	$<
else
ifeq ($(CONTAINER_BACKGROUND), 1)
run-%: ./scripts/%.sh container-build
	$(CONTAINER_RUNTIME) run $(CONTAINER_RUN_FLAGS) $(CPU) \
		-v "$(CONTAINER_OUT_DIR)/$@:$(CONTAINER_INSTALL_DIR)/out/:Z" \
		-v "$(CONTAINER_BUILD_DIR)/:$(CONTAINER_INSTALL_IR)/builds/:Z" \
		-e FUZZ_CORES=$(FUZZ_CORES) \
		--name "$@-$(CONTAINER_TIMESTAMP)" \
		`cat $(CONTAINER_STAMP)` \
		bash -c "$(CONTAINER_INSTALL_DIR)/$< >$(CONTAINER_INSTALL_DIR)/out/$@-$(CONTAINER_TIMESTAMP).log 2>&1"
else
run-%: ./scripts/%.sh container-build
	$(CONTAINER_RUNTIME) run $(CONTAINER_RUN_FLAGS) $(CPU) `cat $(CONTAINER_STAMP)` $<
endif
endif


build-%: ./scripts/build-%.sh ./data/%
	for i in `seq $(BUILD_INSTANCES)`; do $(MAKE) run-$@ ; sleep 1; done

fuzz-%: ./scripts/fuzz-%.sh ./data/%
	for i in $$(seq 0 $$FUZZ_CORES $$(($(FUZZER_INSTANCES) * $(FUZZ_CORES) - 1))); do $(MAKE) run-$@ CPU=--cpuset-cpus=$$i-$$(($$i + $(FUZZ_CORES) - 1)); sleep 1; done


ifeq ($(CONTAINER_RUNTIME), )
ci-test-wrapper: ./scripts/ci-test-wrapper.sh
	$<
else
ci-test-wrapper: ./scripts/ci-test-wrapper.sh container-build
	$(CONTAINER_RUNTIME) run $(CONTAINER_RUN_FLAGS) $(CPU) `cat $(CONTAINER_STAMP)` $<
endif

.PHONY: help system-install bump ci-test-wrapper
