const Web3 = require("web3");
const RLP = require("rlp");

const nonce = 8884;
const account = "0x76e2cfc1f5fa8f6a5b3fc4c8f4788f0116861f9b";

var e = RLP.encode([account, nonce] );
const nonceHash = Web3.utils.sha3(Buffer.from(e));
console.log('0x'+nonceHash.substring(26));

