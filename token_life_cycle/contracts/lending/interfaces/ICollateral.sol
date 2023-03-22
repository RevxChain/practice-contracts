// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

interface ICollateralFactory {
    function setupRole(address marketOperator)external;

    function createSafe(address token, address marketOperator)external returns(address);
}

interface ICollateral{
    function _addCollateral_(address user, uint underlyingAmount)external;

    function _withdrawCollateral_(address user, address to, uint underlyingAmount)external;

    function _partialBuyout_(address user, address liquidator, address supplyCore, uint rate)external returns(uint);

    function _fullBuyout_(address user, address liquidator)external;

    function _serviceLiquidate_(address user, address supplyCore, uint debt)external;

    function _emergencyReplenishment_(address supplyCore, uint totalSupply)external returns(uint);

    function reserve()external view returns(uint);

    function totalCollateral()external view returns(uint);

    function collateralAmount(address user)external view returns(uint);
}
