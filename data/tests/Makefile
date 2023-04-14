DEFAULT_BUILDS=\
	$(CONSTRAINT_SOLVING_TESTS) \
	$(ACCESS_CONTROL_TESTS) \
	$(REENTRANCY_TESTS) \
	$(OTHERS) \
	$(CAPTURE_THE_ETHER)

CONSTRAINT_SOLVING_TESTS=\
	number_equals_constant.combined.json \
	number_equals_storage.combined.json \
	number_equals_computed_constant.combined.json \
	number_equals_constant_large.combined.json \
	number_equals_storage_large.combined.json \
	number_equals_storage_small.combined.json \
	number_equals_storage_hashed.combined.json \
	number_equals_computed_constant_large.combined.json \
	number_equals_computed_constant_large_require.combined.json \
	number_constraints.combined.json \
	calldata1.combined.json \
	calldata2.combined.json \
	calldata3.combined.json \
	calldata4.combined.json \
	callvalue.combined.json \
	callvalue2.combined.json \
	callvalue3.combined.json \
	initbalance.combined.json \
	initbalance2.combined.json \
	ReturnDataCheck.combined.json \
	ReturnDataCheck2.combined.json \
	ReturnDataCheck3.combined.json \
	ReturnDataCheck4.combined.json \
	ReturnDataCheck5.combined.json \
	ReturnDataCheck6.combined.json \
	ReturnDataCheck7.combined.json \
	ReturnDataCheckMultiple.combined.json \
	boolean_selector.combined.json \
	single.combined.json \
	multi.combined.json \
	cstate.combined.json \
	cstate_req.combined.json \
	multi_hard.combined.json \
	justlen128.combined.json \
	harvey_foo.combined.json \
	harvey_baz.combined.json \
	keccak2.combined.json \
	keccak3.combined.json \
	keccak3nopure.combined.json \
	keccak4.combined.json \
	mutual_data_dep.combined.json \
	teether_test_approve.combined.json \
	teether_test1_simple.combined.json \
	teether_test2_singlesha.combined.json \
	teether_test2_singleshamod.combined.json \
	teether_test3_doublesha.combined.json \
	teether_test14_multiowned.combined.json \
	teether_test22.combined.json \
	crytic_complex_example.combined.json \
	integer_overflow.combined.json \
	boom_suicidal.combined.json \
	boom_suicidal_hard.combined.json \
	timestamp.combined.json \
	dispenser.combined.json \
	basic.combined.json \
	basic_hard.combined.json

ACCESS_CONTROL_TESTS=\
	Suicidal.combined.json \
	SuicidalDoSOnly.combined.json \
	SuicidalWithCondition.combined.json \
	SuicidalWithMagicValueCondition.combined.json \
	suicide_multitx_feasible.combined.json \
	Delegatecall.combined.json \
	ParityWalletBugCallArg.combined.json \
	ParityWalletBugCall.combined.json \
	ParityWalletBugSuicide.combined.json \
	simpleetherdrain.combined.json \
	simpleetherdrainother.combined.json

REENTRANCY_TESTS=\
	SimpleDAONoBranch.combined.json \
	SimpleDAO.combined.json \
	SimpleDAORequire.combined.json \
	CrossFunctionToken.combined.json \
	modifier_reentrancy.combined.json \
	modifier_reentrancy_mod.combined.json \
	modifier_reentrancy_mod2.combined.json \
	modifier_reentrancy_mod3.combined.json \
	reentrancy_etherstore.combined.json \
	UnconditionalReentrancyVulnBank.combined.json \
	ReentrancyVulnBankBuggyLock.combined.json \
	ReentrancyVulnBankBuggyLockHard.combined.json \
	ReentrancyBuggyLock2.combined.json \
	SpankchainLedgerChannel-combined-json \
	ReentrancyReturnDataCheck.combined.json \
	ReentrancyDeepCrossFunction.combined.json \
	ReentrancyDeepCrossFunctionSelfdestruct.combined.json \
	ReentrancyDeepCrossFunctionMultiAttacker.combined.json \
	ReentrancyDeepCrossFunctionMultiAttackerLevels.combined.json \
	ReentrancyRegisterCallback.combined.json \
	reentrancy_splits.combined.json

OTHERS=\
	BuggyToken.combined.json \
	crowdsale_mod.combined.json \
	baby_bank.combined.json \
	baby_bank_mod.combined.json

# a set of challenges taken from https://capturetheether.com/challenges/
CAPTURE_THE_ETHER=\
	GuessTheNumberChallenge.combined.json \
	GuessTheNumberChallengeMod1.combined.json \
	GuessTheSecretNumberChallenge.combined.json \
	GuessTheSecretNumberChallengeMod.combined.json \
	GuessTheRandomNumberChallengeMod.combined.json \
	PredictTheFutureChallenge.combined.json \
	PredictTheBlockHashChallenge.combined.json \
	tokensalechallenge.combined.json \
	TokenWhaleChallenge.combined.json \
	FiftyYearsChallenge.combined.json \
	DonationChallenge-combined-json

# this one somehow causes a fault in the constructor?
	#GuessTheRandomNumberChallenge.combined.json \

all: print-env $(DEFAULT_BUILDS)
	# some real contracts
	# doesn't contain a vuln
	#$(MAKE) SOLC_VERSION=0.4.11 grid.combined.json
	#$(MAKE) SOLC_VERSION=0.4.11 projectkudos.combined.json
	# integer overflow contracts (lack of ether oracle)
	#$(MAKE) SOLC_VERSION=0.4.19 EthConnectPonzi.combined.json
	#$(MAKE) SOLC_VERSION=0.4.16 BecToken.combined.json
	#$(MAKE) SOLC_VERSION=0.4.18 Hexagon.combined.json
	#$(MAKE) SOLC_VERSION=0.4.15 SMT.combined.json
	#$(MAKE) SOLC_VERSION=0.4.15 UselessEthereumToken.combined.json
	# somehow compiles with an unparsable sourcemap
	#
	# Some old Solidity contracts with storage corruption issues
	$(MAKE) SOLC_VERSION=0.4.25 arbitrary_location_write_simple.combined.json
	# DVPGame needs another colluding ERC20 Token contract...
	#$(MAKE) SOLC_VERSION=0.4.25 DVPGame.combined.json
	# the original crypto roulette is a honeypot and is never exploitable. So
	# we change it slightly to an exploitable version.
	#$(MAKE) SOLC_VERSION=0.4.19 crypto_roulette.combined.json
	$(MAKE) SOLC_VERSION=0.4.19 crypto_roulette_exploitable.combined.json


include ../../sol.Makefile


SpankchainLedgerChannel-combined-json: SpankchainLedgerChannel.sol
	$(MAKE) SpankchainLedgerChannel.combined.json SOLC_VERSION=0.4.23

MappingChallenge-combined-json: MappingChallenge.sol
	$(MAKE) MappingChallenge.combined.json SOLC_VERSION=0.4.21

DonationChallenge-combined-json: DonationChallenge.sol
	$(MAKE) DonationChallenge.combined.json SOLC_VERSION=0.4.21


.PHONY: clean all print-env build-all evm2cpp-all
