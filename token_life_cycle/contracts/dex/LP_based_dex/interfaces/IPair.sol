// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

interface IPair{
    function _swap(address token, uint amount, address to) external returns(uint);

    function _lpMint(address user, uint amount0, uint amount1) external returns(uint ,uint);

    function _lpBurn(address user, uint amount) external returns(uint, uint);

    function _updateReserves()external;

    function getReserves()external view returns(uint , uint);

    function factory()external view returns(address);

    function router()external view returns(address);

    function token0()external view returns(address);

    function token1()external view returns(address);
}
