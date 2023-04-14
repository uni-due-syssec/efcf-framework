const ganache = require("ganache");
const fs = require("fs");
const Web3 = require("web3");

process.on("uncaughtException", function (err) {
  console.error("Error occured!!! (uncaught exception): ", err);
});

// fixed attacker accounts: account_address -> secretKey
const accountKeys = {
  "0x99308484855dfbd3b9310cee9bc96f2a72526dfc":
    "0x2113298823d49a014f0d4b6417b40e2c77b05b5102a70fdab11e54587b193661",
  "0x063ce0ca8b43310b3c74cf0e9b5a5995ced161ec":
    "0x13b374aa77418a2cacfc59a42d1a043d92efad61eee12a3add4034ae58b6ccef",
  "0xbe1a3dd804340f8577435e822ae3a7dbbedfbfa1":
    "0x815db65ba2e188e821fda227439563758c2da326244eddc066829052abf647b0",
  "0x73b75a26f839677a0e1b1e73c7fd2a6f7af0af0b":
    "0xc9f3a76667ad2ffe500ce04047602ed9fd3252f140a53d5fae08b5732574bd7f",
  "0x9f594ec73484ea3882cfe0537028b770c42c1b00":
    "0x92d44692be77d735f8ea3079779816cfd3ab098f0baab5c43eca94768780a63a",
};

const txGasLimit = "0x1500000";
// const txGasPrice = "0x64"; // TODO ??
// default budget 100 ETH, will be updated later based on attack contract
var attackerBudget = "0x" + (100 * Math.pow(10, 18)).toString(16);
const blockTimeInSec = 1;

function initProvider() {
  // see eEVM/fuzz/common/fuzz_init.hpp
  const init_fund = 1n << 192n;

  // check https://www.npmjs.com/package//ganache-cli for options
  const options = {
    fork: { network: "mainnet" },
    miner: {
      //             defaultGasPrice: txGasPrice,
      defaultTransactionGasLimit: txGasLimit,
      blockTime: blockTimeInSec,
    },
    wallet: {
      accounts: Object.values(accountKeys).map((pk) => ({
        secretKey: pk,
        balance: attackerBudget,
      })),
      unlockedAccounts: Array.from(Array(accountKeys.length).keys()),
    },
  };

  return ganache.provider(options);
}

var provider = null;
var web3 = null;

const accounts = Object.keys(accountKeys);
const attackerAcct = accounts[0];

var attackerBalance = BigInt(0);
var victimBalance = BigInt(0);

function launchAttack(contract, targetAddr, config) {
  contract.methods
    .attack()
    .send({
      from: attackerAcct,
    })
    .on("error", function (error) {
      console.error("Error on tx attack(): ", error);
    })
    .on("receipt", function (receipt) {
      // console.log("Receipt for attack()", receipt);
      if (!receipt.status) {
        console.log("!!! Attack failed");
      }

      web3.eth.getBalance(targetAddr).then((balance) => {
        console.log(
          "Victim balance after attack:",
          BigInt(balance),
          ". Loss:",
          victimBalance - BigInt(balance)
        );
      });

      web3.eth.getBalance(contract.options.address).then((balance) => {
        console.log(
          "Attacker balance after attack:",
          BigInt(balance),
          ". Gain:",
          BigInt(balance) - attackerBalance
        );
      });
    });
}

async function deployAttackContract(abi, bytecode, options) {
  const contract = new web3.eth.Contract(abi);
  const deployOpt = {
    data: bytecode,
    arguments: [options.targetAddress],
  };
  const estimatedGas = await contract.deploy(deployOpt).estimateGas({
    from: attackerAcct,
    gas: 150000000,
    value: options.budget,
  });

  console.log("deploying attack contract");
  contract
    .deploy(deployOpt)
    .send({
      from: attackerAcct,
      gas: estimatedGas,
      value: options.budget,
    })
    .on("error", function (err) {
      console.error("Deploying the attack contract failed ", err);
    })
    .on("receipt", function (receipt) {
      // console.log("Deploy contract receipt: ", receipt);
    })
    .then((deployed) => {
      console.log(`Attack contract deployed at '${deployed.options.address}'`);

      // subscribe events
      deployed.events
        .StateReached()
        .on("error", (err) => console.log("Error on event StateReached: ", err))
        .on("connected", (id) =>
          console.log("Subscription to event StateReached connected:", id)
        )
        .on("data", (event) =>
          console.log("Received event StateReached: ", event)
        );

      deployed.events
        .WaitForBlocks()
        .on("error", (err) =>
          console.log("Error on event WaitForBlocks: ", err)
        )
        .on("connected", (id) =>
          console.log("Subscription to event WaitForBlocks connected:", id)
        )
        .on("data", (event) => {
          console.log("Received event WaitForBlocks: ", event);
          const wait4Block = event.returnValues.count;
          console.log("Waiting for ", wait4Block, " blocks...");
          provider.send(
            {
              method: "evm_increaseTime",
              params: [wait4Block * blockTimeInSec],
            },
            (err, res) => {
              if (err) {
                console.log("Error in evm_increaseTime:", err);
                return;
              }
              console.log("Time advanced for", res.result, "sec.");
              // attack again after advancing block
              launchAttack(deployed, options.targetAddress, options);
            }
          );
        });

      deployed.events
        .AttackFinished()
        .on("error", (err) =>
          console.log("Error on event AttackFinished: ", err)
        )
        .on("connected", (id) =>
          console.log("Subscription to event AttackFinished connected:", id)
        )
        .on("data", (event) => {
          console.log("Received event AttackFinished: ", event);

          web3.eth.personal.newAccount("test").then((address) => {
            console.log("we are calling finishTo(", address, ")");
            deployed.methods
              .finishTo(address)
              .send({
                from: attackerAcct,
              })
              .then(function () {
                web3.eth.getBalance(options.targetAddress).then((balance) => {
                  console.log(
                    "remaining balance of target:",
                    "0x" + BigInt(balance).toString(16)
                  );
                });

                web3.eth.getBalance(address).then((balance) => {
                  console.log(
                    "ether extracted by attack:",
                    "0x" + BigInt(balance).toString(16)
                  );
                });
              });
          });
        });

      web3.eth.getBalance(options.targetAddress).then((balance) => {
        console.log("Victim balance before attack:", balance);
        victimBalance = BigInt(balance);
      });
      web3.eth.getBalance(deployed.options.address).then((balance) => {
        console.log("Attacker balance before attack:", balance);
        attackerBalance = BigInt(balance);
      });

      // initial attack
      launchAttack(deployed, options.targetAddress, options);
    });
}

function parseAttackSourceOptions(source) {
  const options = {};

  options.budget = source
    .split("\n")
    .find((line) => line.includes("constant REQUIRED_BUDGET"))
    .split("=")[1]
    .split(";")[0]
    .trim();
  if (BigInt(attackerBudget, 16) <= BigInt(options.budget, 16)) {
    attackerBudget =
      "0x" +
      (BigInt(attackerBudget, 16) + BigInt(options.budget, 16)).toString(16);
  }

  options.initial_ether = "0x0";

  var initether_line = source
    .split("\n")
    .find((line) => line.includes("constant INITIAL_ETHER"));
  if (initether_line) {
    options.initial_ether = initether_line.split("=")[1].split(";")[0].trim();
  }
  // options.initial_ether = parseInt(options.initial_ether, 16);

  console.log("Attack case options: ");
  console.log(options);
  return options;
}

async function main() {
  if (process.argv.length != 4 && process.argv.length != 5) {
    console.error(
      "Usage: node launch-attack.js <attack_contract.sol> <target_address>"
    );
    console.error(
      "       node launch-attack.js <attack_contract.sol> <bytecode_file> <abi_file>"
    );
    return;
  }
  const source = fs.readFileSync(process.argv[2], "utf8");
  const options = parseAttackSourceOptions(source);

  provider = initProvider();
  web3 = new Web3(provider);

  const input = {
    language: "Solidity",
    sources: {
      contract: { content: source },
    },
    settings: {
      outputSelection: {
        "*": {
          "*": ["*"],
        },
      },
    },
  };
  const solc = require("solc"); // note the solc version
  const output = JSON.parse(solc.compile(JSON.stringify(input)));
  if (!output.contracts) {
    console.error(
      `!!! Error while compiling attacker contract '${process.argv[2]}'`
    );
    console.error(output.errors);
    return;
  }
  // Contract name fixed as "Attack"
  const abi = output.contracts.contract.Attack.abi;
  const bytecode = "0x" + output.contracts.contract.Attack.evm.bytecode.object;

  if (process.argv.length == 4) {
    options.targetAddress = process.argv[3];
    deployAttackContract(abi, bytecode, options);
  } else {
    // deploy the crafted victim contract
    const tgt_bytecode = "0x" + fs.readFileSync(process.argv[3]);
    const tgt_abi = JSON.parse(fs.readFileSync(process.argv[4]));
    const contract = new web3.eth.Contract(tgt_abi);
    contract.options.data = tgt_bytecode.replace("\n", "");
    const esitmated = await contract.deploy().estimateGas({
      from: attackerAcct,
      gas: 15000000000,
    });
    contract
      .deploy()
      .send({
        from: attackerAcct,
        gas: esitmated,
      })
      .on("error", (err) => {
        console.error("error during deploy of target contract: ", err);
      })
      .then((deployed) => {
        console.log(
          `Target contract deployed at '${deployed.options.address}'`
        );
        options.targetAddress = deployed.options.address;
        console.log("deploying attack contract");
        deployAttackContract(abi, bytecode, options);
      });
  }
}

async function estimateGas(contract, value) {
  contract
    .deploy()
    .estimateGas(
      { from: attackerAcct, gas: 15000000000 },
      function (err, gas) {}
    );
}

main();
