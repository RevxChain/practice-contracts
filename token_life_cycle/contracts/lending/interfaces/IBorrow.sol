// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

interface IBorrowFactory {
    function setupRole(address marketOperator)external;

    function createBorrowCore(
        address token, 
        address marketOperator,  
        uint baseBorrowRatePerYear,
        uint borrowRatePerYearMultiplier,
        uint ultimateBorrowRatePerYear,
        uint mathCoefficient,
        uint kink, 
        uint loanToValue, 
        uint liquidationThreshold
    )external returns(address);
}

interface IBorrow{
    function totalBorrows()external view returns(uint);

    function borrow(address user)external view returns(uint);

    function _borrow_(address user, uint underlyingAmount)external;

    function _checkOverCollateralRate_(address user, uint collateralAmount)external view returns(int, uint, uint);

    function _checkOverLTV_(address user, uint collateralAmount)external view returns(int);

    function _withdrawCollateral_(address user, uint collateralAmount, uint underlyingAmount)external;

    function _redeem_(address user, uint underlyingAmount)external;

    function _liquidate_(address user, address liquidator)external returns(uint);

    function _serviceLiquidate_(address user, uint reserve)external returns(uint);

    function _checkOverLTVPotentialDecreaseCollateral_(address user, uint collateralAmount, uint decreaseCollateral)external view returns(int);
    
    function _checkOverLTVPotentialIncreaseBorrow_(address user, uint collateralAmount, uint increaseBorrow)external view returns(int);
}
