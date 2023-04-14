DEFAULT_BUILDS=\
	multi_gen_2.combined.json \
	multi_gen_2 \
	multi_gen_3.combined.json \
	multi_gen_3 \
	multi_gen_4.combined.json \
	multi_gen_4 \
	multi_gen_5.combined.json \
	multi_gen_5 \
	multi_gen_6.combined.json \
	multi_gen_6 \
	multi_gen_7.combined.json \
	multi_gen_7 \
	multi_gen_8.combined.json \
	multi_gen_8 \
	multi_gen_9.combined.json \
	multi_gen_9 \
	multi_gen_10.combined.json \
	multi_gen_10 \
	multi_simple_10 \
	multi_simple_10.combined.json \
	multi_man_complex_5 \
	multi_man_complex_5.combined.json \
	multi_man_complex_7 \
	multi_man_complex_7.combined.json \
	multi_man_complex_9 \
	multi_man_complex_9.combined.json \
	justlen8 \
	justlen8.combined.json \
	justlen64 \
	justlen64.combined.json \
	justlen128 \
	justlen128.combined.json \
	justlen256 \
	justlen256.combined.json

all: print-env $(DEFAULT_BUILDS)

SOLC_ARGS=--evm-version homestead

include ../../sol.Makefile


.PHONY: clean all print-env build-all evm2cpp-all
