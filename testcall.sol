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
            emit Ok(addr, data, amount);
            return true;
        } else {
            emit Failed(false);
            return false;
        }
    }   

    // function setErc20Addr(address addr) public returns(bool) {
    //     erc20 = Erc20(addr);
    // }

    // Erc20  public erc20 ;
    // function exec(address addr, bytes data, uint256 amount)  public payable returns(bool){
    //     bool success = erc20.dosomthing();
    //     if(success) {
    //         emit Ok(addr, data, amount);
    //         return true;
    //     } else {
    //         emit Failed(false);
    //         return false;
    //     }
    // }   
}