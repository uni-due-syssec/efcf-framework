
all: print-env $(DEFAULT_BUILDS)


include ../../../../sol.Makefile

ifeq ($(CONTAINER_RUNTIME), )
uniswap.evm2cpp: ERC1820Registry.combined.json exchange_factory.mock.combined.json IMBTC.combined.json uniswap.abi uniswap.bin-runtime uniswap.bin 
	evm2cpp -e $(EEVM_DIR) -a uniswap.abi uniswap uniswap.bin-runtime uniswap.bin
	evm2cpp -e $(EEVM_DIR) IMBTC IMBTC.combined.json
	evm2cpp -e $(EEVM_DIR) ERC1820Registry ERC1820Registry.combined.json
	evm2cpp -e $(EEVM_DIR) ExchangeFactory exchange_factory.mock.combined.json
endif



.PHONY: clean all print-env build-all evm2cpp-all
