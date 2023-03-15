// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

interface IFactory{
    function pair(address token0, address token1)external view returns(address);

    function createPair(address token0, address token1)external returns(address); 
}
