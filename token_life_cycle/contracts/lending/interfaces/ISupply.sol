// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

interface ISupplyFactory {
    function setupRole(address marketOperator)external;

    function createSToken(address token, address marketOperator)external returns(address);  
}

interface ISupply{
    function _addSupply_(address user, uint underlyingAmount, uint totalLiquidity)external;

    function _withdrawSupply_(address user, uint sTokensAmount, uint totalLiquidity)external returns(uint);

    function _convertSupplyToCollateral_(address user, address collateralCore, uint sTokensAmount, uint totalLiquidity)external returns(uint);

    function _borrow_(address user, uint underlyingAmount)external;

    function _redeem_(uint underlyingAmount)external;

    function _liquidate_(address user)external;

    function supply()external view returns(uint);
}
