// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract AirDrop is AccessControl {

    uint public nonce;

    address public tokenAddress;

    event AirDropExecuted(uint indexed amount, uint indexed nonce, uint time);
    event ReceiveFail(address indexed to, uint indexed nonce, uint amount);

    constructor(address _tokenAddress){
        _setupRole(DEFAULT_ADMIN_ROLE, tx.origin);
        tokenAddress = _tokenAddress;
    }

    function sendAirDropEqualAmount(address[] memory _list, uint _amount)external onlyRole(DEFAULT_ADMIN_ROLE){
        require(_list.length * _amount <= IERC20(tokenAddress).balanceOf(address(this)), "AirDrop: Insufficient total balance");
        nonce += 1;
        uint beforeAmount = IERC20(tokenAddress).balanceOf(address(this));
        for(uint i; i < _list.length; i++){
            (bool success, ) = tokenAddress.call(
                abi.encodeWithSignature("transfer(address,uint256)", _list[i], _amount)
            );
            if(!success){
                emit ReceiveFail(_list[i], nonce, _amount);
            }
        }

        emit AirDropExecuted(beforeAmount - IERC20(tokenAddress).balanceOf(address(this)), nonce, block.timestamp);
    }

    function sendAirDropByList(address[] memory _list, uint[] memory _amounts)external onlyRole(DEFAULT_ADMIN_ROLE){
        uint beforeAmount = IERC20(tokenAddress).balanceOf(address(this));
        nonce += 1;
        require(_list.length == _amounts.length, "AirDrop: Different lengths of arrays");
        for(uint i; i < _list.length; i++){
            (bool success, ) = tokenAddress.call(
                abi.encodeWithSignature("transfer(address,uint256)", _list[i], _amounts[i])
            );
            if(!success){
                emit ReceiveFail(_list[i], nonce, _amounts[i]);
            } 
        }

        emit AirDropExecuted(beforeAmount - IERC20(tokenAddress).balanceOf(address(this)), nonce, block.timestamp);
    }   
}

