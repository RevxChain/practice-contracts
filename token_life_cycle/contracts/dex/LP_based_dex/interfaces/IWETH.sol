// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

interface IWETH{
    function deposit()external payable;

    function transfer(address to, uint value)external returns(bool);

    function transferFrom(address from, address to, uint value)external; 

    function withdraw(uint value)external;  
}
