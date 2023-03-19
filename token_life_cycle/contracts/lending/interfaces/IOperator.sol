// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

interface IOperatorFactory {
    function operator(address token)external returns(address);

    function coreAddresses(address token)external view returns(address operator, address supplyCore, address borrowCore, address collateralCore);

    function createMarket(
        address token, 
        uint baseBorrowRatePerYear,
        uint borrowRatePerYearMultiplier,
        uint ultimateBorrowRatePerYear,
        uint mathCoefficient,
        uint kink, 
        uint loanToValue, 
        uint liquidationThreshold
    )external returns(address);   

}

interface IOperator{

    function initialize(        
        address supplyFactory, 
        address borrowFactory, 
        address collateralFactory,
        uint baseBorrowRatePerYear,
        uint borrowRatePerYearMultiplier,
        uint ultimateBorrowRatePerYear,
        uint mathCoefficient,
        uint kink,  
        uint loanToValue,  
        uint liquidationThreshold
    )external;

    function _addSupply(address user, uint underlyingAmount)external;

    function _withdrawSupply(address user, uint underlyingAmount)external returns(uint);

    function _addCollateral(address user, uint underlyingAmount)external returns(address);

    function _convertSupplyToCollateral(address user, uint sTokensAmount)external returns(uint);

    function _withdrawCollateral(address user, uint underlyingAmount)external;

    function _convertCollateralToSupply(address user, uint underlyingAmount)external;

    function _borrow(address user, uint underlyingAmount)external;

    function _redeem(address user, uint underlyingAmountt)external;

    function _liquidate(address user, address liquidator, uint rate)external returns(address, uint);

    function _serviceLiquidate(address user)external;

    function _checkOverCollateralRate(address user)external view returns(int balance, uint collateral, uint borrow);

    function _checkOverLTV(address user)external view returns(int valueToLiquidate);

    function _checkOverLTVPotentialDecreaseCollateral(address user, uint decreaseCollateral)external view returns(int collateral);

    function _checkOverLTVPotentialIncreaseBorrow(address user, uint increaseBorrow)external view returns(int collateral);

    function utilizationRate()external view returns(uint);

    function supplyCore()external view returns(address);

    function borrowCore()external view returns(address);

    function collateralCore()external view returns(address);
    
}
