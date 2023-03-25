// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

contract AirDrop is AccessControl, ReentrancyGuard {
    using SafeERC20 for IERC20;

    uint public airDropAmount;

    address public token;

    bytes32 public merkleRoot;

    mapping(bytes32 => mapping(address => bool)) public claimed;

    event Claimed(address indexed user, uint indexed amount, uint time);

    constructor(){
        _setupRole(DEFAULT_ADMIN_ROLE, tx.origin);
    }

    function setNewData(address _token, bytes32 _merkleRoot, uint _airDropAmount)external nonReentrant() onlyRole(DEFAULT_ADMIN_ROLE){
        token = _token;
        merkleRoot = _merkleRoot;
        airDropAmount = _airDropAmount;
    }

    function claim(bytes32[] calldata _proof)external nonReentrant(){
        address _user = msg.sender;
        require(IERC20(token).balanceOf(address(this)) >= airDropAmount, "AirDrop: Not enough tokens");
        require(claimed[merkleRoot][_user] == false, "AirDrop: Claimed already"); 
        bytes32 _leaf = keccak256(abi.encode(_user));
        bool result = MerkleProof.verifyCalldata(_proof, merkleRoot, _leaf);
        require(result == true, "AirDrop: You are not whitelisted");
        IERC20(token).safeTransfer(_user, airDropAmount);
        claimed[merkleRoot][_user] = true;

        emit Claimed(_user, airDropAmount, block.timestamp); 
    }
}
