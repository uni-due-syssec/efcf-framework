GIT_PROJECT_ROOT:=$(shell dirname $(realpath $(lastword $(MAKEFILE_LIST))))

FUZZER_INSTANCES=1
FUZZ_CORES=1
FUZZING_REPETITIONS=""
FUZZING_TIME=""
FUZZ_MODES=""
BUILD_INSTANCES=1

UPDATE_MODULES=1
CLEAN_CHECKOUT=0

CONTAINER_ROOT_DIR:=$(GIT_PROJECT_ROOT)/docker/
CONTAINER_RUNTIME:=$(shell command -v podman || command -v docker)
CONTAINER_INSTALL_DIR=/efcf/
CONTAINER_TIMESTAMP:=$(shell date +%Y-%m-%dT%H-%M-%S)
CONTAINER_OUT_DIR:=$(GIT_PROJECT_ROOT)/results/
CONTAINER_BUILD_DIR:=$(GIT_PROJECT_ROOT)/builds/
ifeq ($(CONTAINER_BACKGROUND), 1)
CONTAINER_RUN_FLAGS=-d --net=host --security-opt seccomp=unconfined --oom-score-adj=1000 -w "$(CONTAINER_INSTALL_DIR)" -v "$(GIT_PROJECT_ROOT)/scripts:$(CONTAINER_INSTALL_DIR)/scripts:z" -v "$(GIT_PROJECT_ROOT)/builds:$(CONTAINER_INSTALL_DIR)/builds:z" --tmpfs "$(CONTAINER_INSTALL_DIR)/src/eEVM/fuzz/out/":size=3g --tmpfs "/tmp/efcf/":exec,size=3g --tmpfs "/tmp/efcf-fuzz/":exec,size=3g -v "$(GIT_PROJECT_ROOT)/builds/.ccache:$(CONTAINER_INSTALL_DIR)/ccache:z" -v "$(GIT_PROJECT_ROOT)/results:$(CONTAINER_INSTALL_DIR)/results" -e FUZZING_REPETITIONS=$(FUZZING_REPETITIONS) -e FUZZING_TIME=$(FUZZING_TIME) -e FUZZ_MODES="$(FUZZ_MODES)" -e FUZZ_CORES=$(FUZZ_CORES)
else
CONTAINER_RUN_FLAGS=--rm -it --net=host -v $(GIT_PROJECT_ROOT):$(GIT_PROJECT_ROOT):z -w `realpath $$PWD` -e CCACHE_DIR=$(GIT_PROJECT_ROOT)/builds/.ccache --tmpfs "/tmp/efcf/":exec,size=8g --tmpfs "/tmp/efcf-fuzz/":exec,size=8g
endif
CONTAINER_IMAGE=efcf
CONTAINER_BASE=ubuntu
CONTAINER_TAG=$(CONTAINER_BASE)-$(shell git rev-parse --abbrev-ref HEAD)
RELEASE_TAG=$(CONTAINER_BASE)-$(shell date '+%Y-%m-%d_%H-%M')-$(shell git rev-parse --short HEAD)
CONTAINER_DOCKERFILE=$(CONTAINER_ROOT_DIR)/$(CONTAINER_BASE).Dockerfile
CONTAINER_STAMP=$(CONTAINER_ROOT_DIR)/$(CONTAINER_BASE).BUILT

JUPYTER_IMAGE=docker.io/jupyter/datascience-notebook


.PHONY: container-env container-enter container-build container-clean container-tag container-release gitmodules run-analysis-container

container-build: $(CONTAINER_STAMP) container-env gitmodules

container-env:
	@echo "GIT_CHECKOUT_DIR    = $(GIT_CHECKOUT_DIR)"
	@echo "GIT_PROJECT_ROOT    = $(GIT_PROJECT_ROOT)"
	@echo "CONTAINER_ROOT_DIR  = $(CONTAINER_ROOT_DIR)"
	@echo "CONTAINER_STAMP     = $(CONTAINER_STAMP)"
	@echo "CONTAINER_RUNTIME   = $(CONTAINER_RUNTIME)"
	@echo "CONTAINER_RUN_FLAGS = $(CONTAINER_RUN_FLAGS)"
	@echo "CONTAINER_IMAGE     = $(CONTAINER_IMAGE)"
	@echo "CONTAINER_BASE      = $(CONTAINER_BASE)"
	@echo "CONTAINER_TAG       = $(CONTAINER_TAG)"
	@echo "CONTAINER_OUT_DIR   = $(CONTAINER_OUT_DIR)"

ifeq ($(CLEAN_CHECKOUT), 1)
GIT_CHECKOUT_DIR:=$(shell mktemp -u --suffix=.efcf.repo)

$(GIT_CHECKOUT_DIR):
	@echo "[+] performing clean checkout in $(GIT_CHECKOUT_DIR)"
	test -L ../eevm.git || ln -s $(shell realpath ./src/eEVM) ../eevm.git
	test -L ../ethmutator.git || ln -s $(shell realpath ./src/ethmutator) ../ethmutator.git
	test -L ../evm2cpp.git || ln -s $(shell realpath ./src/evm2cpp) ../evm2cpp.git
	git clone --depth=1 \
		"file://$(shell git rev-parse --show-toplevel)" \
		$(GIT_CHECKOUT_DIR)
	cd $(GIT_CHECKOUT_DIR) && git submodule update --init
	cd $(GIT_CHECKOUT_DIR)/src/eEVM && git submodule update --init
else
GIT_CHECKOUT_DIR:=$(CONTAINER_ROOT_DIR)/../
endif

$(CONTAINER_STAMP): $(CONTAINER_DOCKERFILE) $(GIT_CHECKOUT_DIR)
	$(CONTAINER_RUNTIME) build \
		-q \
		-f $(CONTAINER_DOCKERFILE) \
		-t $(CONTAINER_IMAGE):$(CONTAINER_TAG) \
		-t $(CONTAINER_IMAGE):latest \
		--build-arg ETHERSCAN_API_KEY=$(shell cat .etherscan_api_key) \
		$(GIT_CHECKOUT_DIR) \
		> $(CONTAINER_STAMP) \
		|| (rm $(CONTAINER_STAMP) && false)

container-enter: $(CONTAINER_STAMP)
	$(CONTAINER_RUNTIME) run $(CONTAINER_RUN_FLAGS) `cat $(CONTAINER_STAMP)`

container-clean:
	$(CONTAINER_RUNTIME) rmi $(CONTAINER_IMAGE):latest || true
	$(CONTAINER_RUNTIME) rmi $(CONTAINER_IMAGE):$(CONTAINER_TAG) || true
	$(CONTAINER_RUNTIME) rmi $(shell cat $(CONTAINER_STAMP)) || $(RM) $(CONTAINER_STAMP)
	-$(RM) $(CONTAINER_STAMP)

container-tag: $(CONTAINER_STAMP)
	$(CONTAINER_RUNTIME) tag `cat $(CONTAINER_STAMP)` $(CONTAINER_IMAGE):latest

gitmodules:
ifeq ($(UPDATE_MODULES), 1)
	@echo "[+] updating submodules"
	git submodule update --init
	cd ./src/eEVM && git submodule update --init
endif
ifeq ($(UPDATE_MODULES), bump)
	$(MAKE) bump
endif
	@true

container-release: 
	$(CONTAINER_RUNTIME) build \
		--squash \
		-f $(CONTAINER_DOCKERFILE) \
		-t efcf:$(RELEASE_TAG) \
		--build-arg ETHERSCAN_API_KEY="" \
		--build-arg REMOVE_GIT_DIR=1 \
		$(GIT_CHECKOUT_DIR)
	$(CONTAINER_RUNTIME) save -o efcf-$(RELEASE_TAG).tar efcf:$(RELEASE_TAG)

run-analysis-container:
	cd results && chmod 777 . && \
		$(CONTAINER_RUNTIME) \
		run -it --rm \
		-p 8888:8888 \
		-v $(shell realpath ./results):/home/jovyan/efcf_analysis:Z \
		$(JUPYTER_IMAGE)
