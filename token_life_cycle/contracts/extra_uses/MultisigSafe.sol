// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract MultiSigSafe is AccessControl {
    using SafeERC20 for IERC20;

    uint public ownersCount;
    uint public immutable ownersMax;
    uint public constant TRANSACTION_DURATION = 1 weeks;
    
    address public immutable tokenAddress;

    bool public closed;

    address[] public owners;
    Transaction[] public transactions;

    mapping(address => bool) public ownerCheck;
    mapping(uint => mapping(address => bool)) public confirmed;

    event OwnersSetUp (address indexed _address, uint _time);
    event TxSetUp (uint indexed _txId, address indexed _to, uint indexed _value);
    event TxConfirm (uint indexed _txId, address indexed _address, uint _time);
    event TxExecuted (uint indexed _txId, uint _time, uint _blockNum);

    modifier onlyOwners() {
        require(ownerCheck[msg.sender] == true, "MSS: You are not an owner");
        _;
    }

    modifier txExist(uint _txId) {
        require(transactions.length >= _txId, "MSS: Transaction doesnt exist");
        require(_txId > 0, "MSS: Transaction doesnt exist" );
        _;
    }
  
    constructor(address _tokenAddress, uint _count) {
        _setupRole(DEFAULT_ADMIN_ROLE, tx.origin);
        tokenAddress = _tokenAddress;
        ownersMax = _count;
        if (_count == 1){
            closed = true;
        }
        owners.push(tx.origin);
        ownerCheck[tx.origin] = true;
        ownersCount += 1;
    }
    
    struct Transaction {
        uint txId;
        address to;
        string data;
        uint value;       
        uint deadline;
        uint numConfirmations;
        uint executionBlockNum;
        uint executionTime;
        bool executed;
    }

    function addOwner(address _address) external onlyOwners() onlyRole(DEFAULT_ADMIN_ROLE){
        require(closed == false, "MSS: All owners already added");
        require(ownersCount < ownersMax, "MSS: All owners already added");
        require(_address != address(0), "MSS: You cant add zero address");
        require(ownerCheck[_address] == false, "MSS: You cant add same address one more time");
        owners.push(_address);
        ownerCheck[_address] = true;
        ownersCount += 1;
        if (ownersCount == ownersMax){
            closed = true;

            emit OwnersSetUp(address(this), block.timestamp);
        }
    }

    function txSetUp(address _to, string memory _data, uint _value, uint _deadline) external onlyOwners() {
        require(_deadline - block.timestamp >= TRANSACTION_DURATION, "MSS: It is not enough time");
        require(closed == true, "MSS: All owners are not added already");
        uint _txId = transactions.length + 1;
        Transaction memory transaction = Transaction(_txId, _to, _data, _value, _deadline, 0, 0, 0, false); 
        transactions.push(transaction); 

        emit TxSetUp (_txId, _to, _value);
    }

    function txConfirm(uint _txId) external onlyOwners() txExist(_txId) {
        address _user = msg.sender;
        require(transactions[_txId-1].deadline > block.timestamp, "MSS: Transaction's deadline is expired");
        require(transactions[_txId-1].executed == false, "MSS: Transaction is already executed");
        require(confirmed[_txId][_user] == false, "MSS: You are already confirmed this transaction");
        confirmed[_txId][_user] = true;
        transactions[_txId-1].numConfirmations +=1;
        if (transactions[_txId-1].numConfirmations == ownersMax){
            _txExecution( _txId);
        }

        emit TxConfirm (_txId, _user, block.timestamp);
    }
    
    function _txExecution(uint _txId) private onlyOwners() txExist(_txId) {
        require(IERC20(tokenAddress).balanceOf(address(this)) >= transactions[_txId-1].value, "MSS: Is not enough value for execution");
        transactions[_txId-1].executed = true;
        transactions[_txId-1].executionTime = block.timestamp;
        transactions[_txId-1].executionBlockNum = block.number;
        IERC20(tokenAddress).safeTransfer(transactions[_txId-1].to, transactions[_txId-1].value);

        emit TxExecuted (_txId, block.timestamp, block.number); 
    }

    function _checkBalance() external view returns(uint) {
        return IERC20(tokenAddress).balanceOf(address(this));
    }
}  
