const Web3 = require("web3");
const RLP = require("rlp");

const account = "0x76e2cfc1f5fa8f6a5b3fc4c8f4788f0116861f9b";

for (let nonce = 0; nonce < 0xffffffff; nonce++){
    let e = RLP.encode([account, nonce] );
    const nonceHash = Web3.utils.sha3(Buffer.from(e));
    const targetAddress = '0x'+ nonceHash.substring(26)
    if(targetAddress === '0x4f3a120e72c76c22ae802d129f599bfdbc31cb81') {
        console.log(nonce)
        break
    }
}



// 目标地址: 0x4f3a120e72c76c22ae802d129f599bfdbc31cb81 