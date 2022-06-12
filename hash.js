const Web3 = require("web3");


console.log( Web3.utils.sha3("owner()").substr(0, 10))
console.log(Web3.utils.sha3("exec(address,bytes,uint256)").substr(0, 10))