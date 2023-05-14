import Web3 from "web3";
import {prompt} from 'enquirer'
import dotenv from 'dotenv';
import path from 'path';
import {Spinner} from 'cli-spinner';
import * as circomlib from 'circomlib';
import * as snarkjs from 'snarkjs';
import * as assert from "assert";
import * as fs from "fs";
import * as merkleTree from "fixed-merkle-tree";
import * as websnarkUtils from 'websnark/src/utils';
import * as buildGroth16 from 'websnark/src/groth16';

let circuit, proving_key, groth16;
const CONTRACT_ADDRESS = '0x6Bf694a291DF3FeC1f7e69701E3ab6c592435Ae7'
const RPC_URL = 'https://rpc.goerli.eth.gateway.fm'
const web3 = new Web3(new Web3.providers.HttpProvider(RPC_URL, { timeout: 5 * 60 * 1000 }), null)
const tornadoContract = new web3.eth.Contract(require(__dirname + '/../build/contracts/ETHTornado.json').abi, CONTRACT_ADDRESS)

dotenv.config({
  path: path.join(__dirname, '..', '.env'),
});


interface Deposit {
  nullifier;
  secret;
  preimage;
  commitment;
  commitmentHex;
  nullifierHash;
}

const bigInt = snarkjs.bigInt;
/** Compute pedersen hash */
const pedersenHash = (data) => circomlib.babyJub.unpackPoint(circomlib.pedersenHash.hash(data))[0];

/** BigNumber to hex string of specified length */
function toHex(number, length = 32) {
  const str = number instanceof Buffer ? number.toString('hex') : bigInt(number).toString(16);
  return '0x' + str.padStart(length * 2, '0');
}

function createDeposit({ nullifier, secret }) {
  const preimage = Buffer.concat([nullifier.leInt2Buff(31), secret.leInt2Buff(31)]);
  const commitment = pedersenHash(preimage)
  const commitmentHex = toHex(commitment);
  const nullifierHash = pedersenHash(nullifier.leInt2Buff(31));
  const deposit: Deposit = {
    nullifier,
    secret,
    preimage,
    commitment,
    commitmentHex,
    nullifierHash,
  };

  return deposit;
}


function parseNote(noteString) {
  const noteRegex = /tornado-(?<currency>\w+)-(?<amount>[\d.]+)-(?<netId>\d+)-0x(?<note>[0-9a-fA-F]{124})/g
  const match = noteRegex.exec(noteString);
  if (!match) {
    throw new Error('The note has invalid format');
  }

  const buf = Buffer.from(match.groups.note, 'hex');
  const nullifier = bigInt.leBuff2int(buf.slice(0, 31));
  const secret = bigInt.leBuff2int(buf.slice(31, 62));
  const deposit = createDeposit({ nullifier, secret });
  const netId = Number(match.groups.netId);

  return {
    currency: match.groups.currency,
    amount: match.groups.amount,
    netId,
    deposit
  }
}

function loadCachedEvents({ type, currency, amount, chainId }) {
  console.log(__dirname + `/../cache/${chainId}/${type}s_${currency}_${amount}.json`)
  try {
    const module = require(__dirname + `/../cache/${chainId}/${type}s_${currency}_${amount}.json`);

    if (module) {
      const events = module;

      return {
        events,
        lastBlock: events[events.length - 1].blockNumber
      }
    }
  } catch (err) {
    console.log("Error fetching cached files, syncing from block 0");
    return {
      events: [],
      lastBlock: 0,
    }
  }
}

async function fetchEvents({ type, currency, amount }) {
  let chainId = await web3.eth.getChainId()
  if (type === "withdraw") {
    type = "Withdrawal";
  }

  const cachedEvents = loadCachedEvents({ type, currency, amount, chainId });
  const startBlock = cachedEvents.lastBlock + 1;

  console.log("Loaded cached",amount,currency.toUpperCase(),type,"events for",startBlock,"block");
  console.log("Fetching",amount,currency.toUpperCase(),type,"events for",chainId,"network");

  async function syncEvents() {
    try {
      let targetBlock = await web3.eth.getBlockNumber();
      let chunks = 300000;
      console.log("Querying latest events from RPC");

      for (let i = startBlock; i < targetBlock; i += chunks) {
        let fetchedEvents = [];

        function mapDepositEvents() {
          fetchedEvents = fetchedEvents.map(({ blockNumber, transactionHash, returnValues }) => {
            const { commitment, leafIndex, timestamp } = returnValues;
            return {
              blockNumber,
              transactionHash,
              commitment,
              leafIndex: Number(leafIndex),
              timestamp
            }
          });
        }

        function mapWithdrawEvents() {
          fetchedEvents = fetchedEvents.map(({ blockNumber, transactionHash, returnValues }) => {
            const { nullifierHash, to, fee } = returnValues;
            return {
              blockNumber,
              transactionHash,
              nullifierHash,
              to,
              fee
            }
          });
        }

        function mapLatestEvents() {
          if (type === "Deposit"){
            mapDepositEvents();
          } else {
            mapWithdrawEvents();
          }
        }

        async function fetchWeb3Events(i) {
          let j;
          if (i + chunks - 1 > targetBlock) {
            j = targetBlock;
          } else {
            j = i + chunks - 1;
          }
          await tornadoContract.getPastEvents(type, {
            fromBlock: i,
            toBlock: j,
          }).then(r => { fetchedEvents = fetchedEvents.concat(r); console.log("Fetched", amount, currency.toUpperCase(), type, "events to block:", j) }, err => { console.error(i + " failed fetching", type, "events from node", err); process.exit(1); }).catch(console.log);

          if (type === "Deposit"){
            mapDepositEvents();
          } else {
            mapWithdrawEvents();
          }
        }

        async function updateCache() {
          try {
            const fileName = __dirname + `/../cache/${chainId}/${type}s_${currency}_${amount}.json`;
            const localEvents: any = await initJson(fileName);
            const events = localEvents.concat(fetchedEvents);
            await fs.writeFileSync(fileName, JSON.stringify(events, null, 2), 'utf8');
          } catch (error) {
            throw new Error('Writing cache file failed');
          }
        }
        await fetchWeb3Events(i);
        await updateCache();
      }
    } catch (error) {
      throw new Error("Error while updating cache");
      process.exit(1);
    }
  }
  await syncEvents();
  async function loadUpdatedEvents() {
    const fileName = __dirname + `/../cache/${chainId}/${type}s_${currency}_${amount}.json`;
    const updatedEvents: any = await initJson(fileName);
    const updatedBlock = updatedEvents[updatedEvents.length - 1].blockNumber;
    console.log("Cache updated for Tornado",type,amount,currency,"instance to block",updatedBlock,"successfully");
    console.log(`Total ${type}s:`, updatedEvents.length);
    return updatedEvents;
  }
  const events = await loadUpdatedEvents();
  return events;
}


function initJson(file) {
  return new Promise((resolve, reject) => {
    fs.readFile(file, 'utf8', (error, data) => {
      if (error) {
        resolve([]);
      }
      try {
        resolve(JSON.parse(data));
      } catch (error) {
        resolve([]);
      }
    });
  });
};

async function generateMerkleProof(deposit, currency, amount) {
  const MERKLE_TREE_HEIGHT = 20
  let leafIndex = -1;
  // Get all deposit events from smart contract and assemble merkle tree from them

  const cachedEvents: any = await fetchEvents({ type: 'Deposit', currency, amount });

  const leaves = cachedEvents
    .sort((a, b) => a.leafIndex - b.leafIndex) // Sort events in chronological order
    .map((e) => {

      const index = web3.utils.toBN(e.leafIndex).toNumber();

      if (web3.utils.toBN(e.commitment).eq(web3.utils.toBN(deposit.commitmentHex))) {
        leafIndex = index;
      }
      return web3.utils.toBN(e.commitment).toString(10);
    });
  const tree = new merkleTree.default(MERKLE_TREE_HEIGHT, leaves);

  // Validate that our data is correct
  const root = tree.root();
  let isValidRoot, isSpent;
  isValidRoot = await tornadoContract.methods.isKnownRoot(toHex(root)).call();
  isSpent = await tornadoContract.methods.isSpent(toHex(deposit.nullifierHash)).call();
  assert.default(isValidRoot === true, 'Merkle tree is corrupted');
  assert.default(isSpent === false, 'The note is already spent');
  assert.default(leafIndex >= 0, 'The deposit is not found in the tree');

  // Compute merkle proof of our commitment
  const { pathElements, pathIndices } = tree.path(leafIndex);
  return { root, pathElements, pathIndices };
}

async function generateProof({ deposit, currency, amount, recipient, relayerAddress, fee = 0, refund = 0 }) {
  // Compute merkle proof of our commitment
  const { root, pathElements, pathIndices } = await generateMerkleProof(deposit, currency, amount);

  // Prepare circuit input
  const input = {
    // Public snark inputs
    root: root,
    nullifierHash: deposit.nullifierHash,
    recipient: bigInt(recipient),
    relayer: bigInt(relayerAddress),
    fee: bigInt(fee),
    refund: bigInt(refund),

    // Private snark inputs
    nullifier: deposit.nullifier,
    secret: deposit.secret,
    pathElements: pathElements,
    pathIndices: pathIndices
  }

  console.log('Generating SNARK proof');
  console.time('Proof time');
  const proofData = await websnarkUtils.genWitnessAndProve(groth16, input, circuit, proving_key);
  const { proof } = websnarkUtils.toSolidityInput(proofData);
  console.timeEnd('Proof time');

  const args = [
    toHex(input.root),
    toHex(input.nullifierHash),
    toHex(input.recipient, 20),
    toHex(input.relayer, 20),
    toHex(input.fee),
    toHex(input.refund)
  ];

  return { proof, args };
}


async function main(){
  circuit = require(__dirname + '/../build/circuits/withdraw.json')
  proving_key = fs.readFileSync(__dirname + '/../build/circuits/withdraw_proving_key.bin').buffer
  groth16 = await buildGroth16.default()
  const questions = [
    {
      type: 'select',
      name: 'operation',
      message: 'Select operation',
      choices: [
        { name: 'parse-note', message: 'Parse Note',},
        { name: 'generate-proof', message: 'Generate Proof',},
        { name: 'deploy-account', message: 'Deploy account',},
      ]
    },
  ];
  let answers: any = await prompt(questions);
  switch (answers.operation){
    case "parse-note":
      await command_parseNote();
      break;
    case "generate-proof":
      await command_generateProof();
      break;
  }
}

async function command_parseNote(){
  const questions = [
    {
      type: 'input',
      name: 'note',
      message: 'Deposit note',
      hint: 'tornado-....',
    },
  ]
  let answers: any = await prompt(questions);
  //
  const parsedNote = parseNote(answers.note);
  console.log(parsedNote);
}

async function command_generateProof(){
  const questions = [
    {
      type: 'input',
      name: 'note',
      message: 'Deposit note',
      hint: 'tornado-....',
    },
    {
      type: 'input',
      name: 'recipient',
      message: 'Recipient',
      hint: '0x4337...1010',
    },
    {
      type: 'input',
      name: 'relayer',
      message: 'Relayer',
      hint: '0x4337...1010',
    },
  ]
  let answers: any = await prompt(questions);
  //
  const {currency, amount, netId, deposit} = parseNote(answers.note);
  const { proof, args } = await generateProof({ deposit, currency, amount, recipient: answers.recipient, relayerAddress: answers.relayer, fee: 0, refund: 0 });
  console.log(proof);
  console.log(args)
}

main();