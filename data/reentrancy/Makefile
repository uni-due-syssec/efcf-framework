
all: print-env
	$(MAKE) SimpleDAO.combined.json SOLC_VERSION=0.7.6
	$(MAKE) ReentrancyVulnBankBuggyLockHard.combined.json SOLC_VERSION=0.7.6
	$(MAKE) ReentrancyVulnBankBuggyLock.combined.json SOLC_VERSION=0.7.6
	$(MAKE) SpankchainLedgerChannel.combined.json SOLC_VERSION=0.4.23
	$(MAKE) lendfme_moneymarket.combined.json SOLC_VERSION=0.4.24
	$(MAKE) BetingHouse_0x0eb68f34efa0086e4136bca51fc4d0696580643e.combined.json SOLC_VERSION=0.5.0
	$(MAKE) DecentralizedExchanges_0x72f60eca0db6811274215694129661151f97982e.combined.json SOLC_VERSION=0.4.24
	$(MAKE) DecentralizedExchanges_0xd4cd7c881f5ceece4917d856ce73f510d7d0769e.combined.json SOLC_VERSION=0.4.24
	$(MAKE) HODLWallet.combined.json SOLC_VERSION=0.4.24
	$(MAKE) UniswapEx.combined.json SOLC_VERSION=0.7.6


include ../../sol.Makefile

ifneq ($(OVERRIDE_EVM2CPP), 1)
ifeq ($(CONTAINER_RUNTIME), )
uniswap.evm2cpp: uniswap.abi uniswap.bin-runtime uniswap.bin 
	evm2cpp -e $(EEVM_DIR) -a uniswap.abi uniswap uniswap.bin-runtime uniswap.bin

DSEthToken_0xd654bdd32fc99471455e86c2e7f7d7b6437e9179.evm2cpp: DSEthToken_0xd654bdd32fc99471455e86c2e7f7d7b6437e9179.abi DSEthToken_0xd654bdd32fc99471455e86c2e7f7d7b6437e9179.bin DSEthToken_0xd654bdd32fc99471455e86c2e7f7d7b6437e9179.bin-runtime
	evm2cpp -e $(EEVM_DIR) -a DSEthToken_0xd654bdd32fc99471455e86c2e7f7d7b6437e9179.abi DSEthToken_0xd654bdd32fc99471455e86c2e7f7d7b6437e9179 DSEthToken_0xd654bdd32fc99471455e86c2e7f7d7b6437e9179.bin DSEthToken_0xd654bdd32fc99471455e86c2e7f7d7b6437e9179.bin-runtime
else
uniswap.evm2cpp: uniswap.abi uniswap.bin-runtime uniswap.bin $(CONTAINER_STAMP)
	$(CONTAINER_RUNTIME) \
		run $(CONTAINER_RUN_FLAGS) \
		-v "$(EEVM_DIR):$(EEVM_DIR):Z" \
		$(shell cat $(CONTAINER_STAMP)) \
		evm2cpp -e $(EEVM_DIR) -a uniswap.abi "$(shell basename "$<" | cut -d '.' -f 1)" uniswap.bin-runtime uniswap.bin

DSEthToken_0xd654bdd32fc99471455e86c2e7f7d7b6437e9179.evm2cpp: DSEthToken_0xd654bdd32fc99471455e86c2e7f7d7b6437e9179.abi DSEthToken_0xd654bdd32fc99471455e86c2e7f7d7b6437e9179.bin DSEthToken_0xd654bdd32fc99471455e86c2e7f7d7b6437e9179.bin-runtime
	$(CONTAINER_RUNTIME) \
		run $(CONTAINER_RUN_FLAGS) \
		-v "$(EEVM_DIR):$(EEVM_DIR):Z" \
		$(shell cat $(CONTAINER_STAMP)) \
		evm2cpp -e $(EEVM_DIR) -a DSEthToken_0xd654bdd32fc99471455e86c2e7f7d7b6437e9179.abi DSEthToken_0xd654bdd32fc99471455e86c2e7f7d7b6437e9179 DSEthToken_0xd654bdd32fc99471455e86c2e7f7d7b6437e9179.bin DSEthToken_0xd654bdd32fc99471455e86c2e7f7d7b6437e9179.bin-runtime
endif
endif

clean:
	-$(RM) *.combined.json *.sourcemap *_storage.json *.signatures *.out
	-$(RM) SimpleDAO.bin ReentrancyVulnBankBuggyLock.bin ReentrancyVulnBankBuggyLockHard.bin \
		SpankchainLedgerChannel.bin lendfme_moneymarket.bin 0x0eb68f34efa0086e4136bca51fc4d0696580643e.bin \
		0x72f60eca0db6811274215694129661151f97982e.bin 0xd4cd7c881f5ceece4917d856ce73f510d7d0769e.bin \
		HODLWallet.bin
	-$(RM) SimpleDAO.bin-runtime ReentrancyVulnBankBuggyLock.bin-runtime \
		ReentrancyVulnBankBuggyLockHard.bin-runtime \
		SpankchainLedgerChannel.bin-runtime lendfme_moneymarket.bin-runtime \
		0x0eb68f34efa0086e4136bca51fc4d0696580643e.bin-runtime \
		0x72f60eca0db6811274215694129661151f97982e.bin-runtime \
		0xd4cd7c881f5ceece4917d856ce73f510d7d0769e.bin-runtime \
		HODLWallet.bin-runtime
	-$(RM) SimpleDAO.abi ReentrancyVulnBankBuggyLock.abi ReentrancyVulnBankBuggyLockHard.abi \
		SpankchainLedgerChannel.abi lendfme_moneymarket.abi 0x0eb68f34efa0086e4136bca51fc4d0696580643e.abi \
		0x72f60eca0db6811274215694129661151f97982e.abi 0xd4cd7c881f5ceece4917d856ce73f510d7d0769e.abi \
		HODLWallet.abi

.PHONY: clean all print-env build-all evm2cpp-all
