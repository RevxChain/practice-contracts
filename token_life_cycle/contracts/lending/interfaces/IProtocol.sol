// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

interface IProtocol{
    function operatorFactory()external returns(address);

    function marketOperator(address token)external returns(address);

    function usingMarkets(address user, uint index)external returns(address);

    function onlyCollateral(address token)external returns(bool);

    function usingMarket(address user, address token)external returns(bool);

    function addSupply(address token, uint underlyingAmount)external;

    function withdrawSupply(address token, uint sTokensAmount)external;

    function addCollateral(address token, uint underlyingAmount)external;

    function convertSupplyToCollateral(address token, uint sTokensAmount)external;

    function withdrawCollateral(address token, uint underlyingAmount)external;

    function convertCollateralToSupply(address token, uint underlyingAmount)external;

    function borrow(address token, uint underlyingAmount)external;

    function redeem(address token, uint underlyingAmount)external;

    function liquidate(address user)external;

    function liquidateCall(address user)external;

    function checkLiquidationPossibility(address user)external view returns(bool uncovered, int totalBalance, uint totalCollateralValue, uint totalBorrowValue);

    function checkOverLTV(address user)external view returns(bool LTVExceed, int totalCollateral);

    function checkOverLTVPotentialDecreaseCollateral(address user, address token, uint decreaseCollateral)external view returns(bool LTVExceed, int totalCollateral);
    
    function checkOverLTVPotentialIncreaseBorrow(address user, address token, uint increaseBorrow)external view returns(bool LTVExceed, int totalCollateral);
}
