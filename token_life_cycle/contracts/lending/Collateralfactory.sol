// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./access/AccessControl.sol";

contract CollateralSafe is AccessControl{
    using SafeERC20 for IERC20;

    uint public totalCollateral;  
    uint public reserve; 
    uint public constant ACCURACY = 1e18;
    uint public constant DIV = 100;

    address public immutable token;
    address public immutable marketOperator;
    address public immutable oracle;

    mapping(address => uint) public collateralAmount; 

    event ActualTotalCollateral(uint totalCollateral, uint time);
    event ActualReserve(uint reserve, uint time);

    constructor(address _token, address _marketOperator, address _oracle){
        token = _token;
        marketOperator = _marketOperator;
        oracle = _oracle;
        _setupRole(DEFAULT_CALLER, _marketOperator);
    }

    function _addCollateral_(address _user, uint _underlyingAmount)external onlyRole(DEFAULT_CALLER){
        collateralAmount[_user] += _underlyingAmount;
        totalCollateral += _underlyingAmount;

        emit ActualTotalCollateral(totalCollateral, block.timestamp);
    }
    
    function _withdrawCollateral_(address _user, address _to, uint _underlyingAmount)external onlyRole(DEFAULT_CALLER){
        totalCollateral -= _underlyingAmount;
        collateralAmount[_user] -= _underlyingAmount;
        IERC20(token).safeTransfer(_to, _underlyingAmount);

        emit ActualTotalCollateral(totalCollateral, block.timestamp);
    }

    function _partialBuyout_(
        address _user, 
        address _liquidator, 
        address _supplyCore, 
        uint _rate
    )
        external 
        onlyRole(DEFAULT_CALLER) 
        returns(uint amountToSupplyAndReserve)
    {
        totalCollateral -= collateralAmount[_user];
        uint amountToLiquidator = collateralAmount[_user] * _rate / ACCURACY;
        amountToSupplyAndReserve = (collateralAmount[_user] - amountToLiquidator) / 3; 
        amountToLiquidator = collateralAmount[_user] - amountToSupplyAndReserve * 2; 
        collateralAmount[_user] = 0;
        IERC20(token).safeTransfer(_liquidator, amountToLiquidator);
        IERC20(token).safeTransfer(_supplyCore, amountToSupplyAndReserve);
        reserve += amountToSupplyAndReserve;

        emit ActualTotalCollateral(totalCollateral, block.timestamp);
        emit ActualReserve(reserve, block.timestamp);
    }   

    function _fullBuyout_(address _user, address _liquidator)public onlyRole(DEFAULT_CALLER){
        totalCollateral -= collateralAmount[_user];
        IERC20(token).safeTransfer(_liquidator, collateralAmount[_user]);
        collateralAmount[_user] = 0;

        emit ActualTotalCollateral(totalCollateral, block.timestamp);
    } 

    function _serviceLiquidate_(address _user, address _supplyCore, uint _debt)external onlyRole(DEFAULT_CALLER){
        _fullBuyout_(_user, _supplyCore);
        IERC20(token).safeTransfer(_supplyCore, _debt);
        reserve -= _debt;

        emit ActualReserve(reserve, block.timestamp);
    }

    function _emergencyReplenishment_(address _supplyCore, uint _totalSupply)external onlyRole(DEFAULT_CALLER) returns(uint amountToReplenish){
        amountToReplenish = _totalSupply / DIV;
        if(amountToReplenish >= reserve / DIV){
            amountToReplenish = reserve / DIV;
        } 
        IERC20(token).safeTransfer(_supplyCore, amountToReplenish);
        reserve -= amountToReplenish;

        emit ActualReserve(reserve, block.timestamp);
    }

    function _updateReserve()external onlyRole(DEFAULT_CALLER){ 
        if(IERC20(token).balanceOf(address(this)) > reserve + totalCollateral){
            reserve = IERC20(token).balanceOf(address(this)) - totalCollateral;

            emit ActualReserve(reserve, block.timestamp);
        }
    }
}

contract CollateralFactory is AccessControl { 

    address public immutable operatorFactory;
    address public immutable oracle;

    mapping(address => bool) public collateralSafeExist;

    constructor(address _oracle, address _operatorFactory){
        oracle = _oracle;
        operatorFactory = _operatorFactory;
        _setupRole(DEFAULT_CALLER, operatorFactory);
    }

    function setupRole(address _marketOperator)external onlyRole(DEFAULT_CALLER){
        _setupRole(DEFAULT_CALLER, _marketOperator);
    }

    function createSafe(address _token, address _marketOperator)external onlyRole(DEFAULT_CALLER) returns(address){
        require(collateralSafeExist[_token] == false, "CollateralFactory: Invalid create");
        CollateralSafe _core = new CollateralSafe(_token, _marketOperator, oracle);
        collateralSafeExist[_token] = true;

        return address(_core);
    }
}
