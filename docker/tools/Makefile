CONTAINER_RUNTIME:=$(shell command -v podman || command -v docker)

all: $(shell ls *.Dockerfile | cut -d . -f 1)

echidnap: echidnaparade

%: %.Dockerfile
	$(CONTAINER_RUNTIME) build -t $@ -f $< .
