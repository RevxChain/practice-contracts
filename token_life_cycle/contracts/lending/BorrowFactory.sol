// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./access/AccessControl.sol";
import "./interfaces/IOperator.sol"; 

interface IOracle {
    function getLatestPrice(address _token)external view returns(uint);
}

contract BorrowCore is AccessControl{
    using SafeERC20 for IERC20;

    uint public totalBorrows; 
    uint public borrowPool; 
    uint public lastUpdateTotalBorrows; 

    uint public immutable baseBorrowRatePerYear; 
    uint public immutable borrowRatePerYearMultiplier; 
    uint public immutable ultimateBorrowRatePerYear; 
    uint public immutable mathCoefficient; 
    uint public immutable kink; 
    uint public immutable loanToValue; 
    uint public immutable liquidationThreshold; 

    uint public constant ONE_YEAR_DURATION = 52 weeks; 
    uint public constant ACCURACY = 1e18;
    uint public constant DIV = 100;
    uint public constant INITIALIZATION_VALUE = 10;

    address public immutable token;
    address public immutable marketOperator;
    address public immutable oracle;

    mapping(address => uint) public borrow; 

    event ActualTotalBorrows(uint totalBorrows, uint time);
    event ActualBorrowRate(uint borrowRatePerYear, uint time);
    
    constructor(
        address _token, 
        address _marketOperator, 
        address _oracle, 
        uint _baseBorrowRatePerYear,
        uint _borrowRatePerYearMultiplier, 
        uint _ultimateBorrowRatePerYear, 
        uint _mathCoefficient,
        uint _kink,
        uint _loanToValue, 
        uint _liquidationThreshold
    ) 
    {
        token = _token;
        marketOperator = _marketOperator;
        oracle = _oracle;
        lastUpdateTotalBorrows = block.timestamp;
        baseBorrowRatePerYear = _baseBorrowRatePerYear;
        borrowRatePerYearMultiplier = _borrowRatePerYearMultiplier; 
        ultimateBorrowRatePerYear = _ultimateBorrowRatePerYear; 
        mathCoefficient = _mathCoefficient; 
        kink = _kink;
        loanToValue = _loanToValue;
        liquidationThreshold = _liquidationThreshold;
        totalBorrows = INITIALIZATION_VALUE;
        borrowPool = INITIALIZATION_VALUE;
        _setupRole(DEFAULT_CALLER, marketOperator);
    }
   
    function _borrow_(address _user, uint _underlyingAmount)external onlyRole(DEFAULT_CALLER){
        updateTotalBorrows();
        uint userShare = _calculateNewBorrowPool(_underlyingAmount) - borrowPool;
        uint newPool = _calculateNewBorrowPool(_underlyingAmount);
        borrowPool = newPool;
        totalBorrows += _underlyingAmount;
        borrow[_user] += userShare;

        emit ActualTotalBorrows(totalBorrows, block.timestamp);
    }

    function _redeem_(address _user, uint _underlyingAmount)external onlyRole(DEFAULT_CALLER){
        updateTotalBorrows();
        uint debt = _calculateUserDebt(_user);
        require(debt >= _underlyingAmount, "BorrowCore: Too many tokens to redeem");
        _redeemInternal(_user, _underlyingAmount);

        emit ActualTotalBorrows(totalBorrows, block.timestamp);
    } 

    function _liquidate_(address _user, address _liquidator)external onlyRole(DEFAULT_CALLER) returns(uint debt){
        updateTotalBorrows();
        debt = _calculateUserDebt(_user);
        require(IERC20(token).balanceOf(_liquidator) >= debt, "BorrowCore: Not enough underlying tokens to buyout");
        _redeemInternal(_user, debt);

        emit ActualTotalBorrows(totalBorrows, block.timestamp);
    } 

    function _serviceLiquidate_(address _user, uint _reserve)external onlyRole(DEFAULT_CALLER) returns(uint debt){
        updateTotalBorrows();
        debt = _calculateUserDebt(_user);
        require(_reserve >= debt, "BorrowCore: Not enough reserve amount to amortization");
        _redeemInternal(_user, debt);

        emit ActualTotalBorrows(totalBorrows, block.timestamp);
    }

    function _redeemInternal(address _user, uint _underlyingAmount)internal {
        require(totalBorrows >= _underlyingAmount, "BorrowCore: Too many tokens to redeem");
        uint sharePoolDecrease = _underlyingAmount * borrowPool / totalBorrows;
        require(borrowPool >= sharePoolDecrease, "BorrowCore: 0x01");
        require(borrow[_user] >= sharePoolDecrease, "BorrowCore: 0x02");
        borrow[_user] -= sharePoolDecrease; 
        if(sharePoolDecrease == borrowPool){
            borrowPool = INITIALIZATION_VALUE;
        } else {
            borrowPool -= sharePoolDecrease;
        }
        if(_underlyingAmount == totalBorrows){
            totalBorrows = INITIALIZATION_VALUE;
        } else {
            totalBorrows -= _underlyingAmount;
        }
    } 

    function updateTotalBorrows()public returns(uint){
        if ((block.timestamp - lastUpdateTotalBorrows) > 0){
            uint totalBorrowsIncrease = 
            (totalBorrows * _calculateActualBorrowRate() * ((block.timestamp - lastUpdateTotalBorrows) * ACCURACY / ONE_YEAR_DURATION)) / (ACCURACY * ACCURACY);
            totalBorrows += totalBorrowsIncrease;
            lastUpdateTotalBorrows = block.timestamp;

            emit ActualBorrowRate(_calculateActualBorrowRate(), block.timestamp);
        }

        return totalBorrows;
    }

    function preUpdateTotalBorrows()public view returns(uint){
        if ((block.timestamp - lastUpdateTotalBorrows) > 0){
            uint totalBorrowsIncrease = 
            (totalBorrows * _calculateActualBorrowRate() * ((block.timestamp - lastUpdateTotalBorrows) * ACCURACY / ONE_YEAR_DURATION)) / (ACCURACY * ACCURACY);
            uint preComputedTotalBorrows = totalBorrows + totalBorrowsIncrease;
            return preComputedTotalBorrows;
        } else {
            return totalBorrows;
        }       
    }

    function _checkOverCollateralRate_(
        address _user, 
        uint _collateralAmount
    )
        public 
        view 
        returns(
            int _balance, 
            uint collateralValue, 
            uint borrowsValue
        )
    { 
        uint _totalBorrows = preUpdateTotalBorrows();
        collateralValue = _collateralAmount * IOracle(oracle).getLatestPrice(token);
        borrowsValue = borrow[_user] * _totalBorrows / borrowPool * IOracle(oracle).getLatestPrice(token);
        _balance = (int(collateralValue) * int(liquidationThreshold) - int(borrowsValue) * int(ACCURACY)) / int(ACCURACY); 
    }

    function _checkOverLTV_(address _user, uint _collateralAmount)public view returns(int _collateral){ 
        uint _totalBorrows = preUpdateTotalBorrows();
        uint collateralValue = _collateralAmount * IOracle(oracle).getLatestPrice(token);
        uint borrowsValue = borrow[_user] * _totalBorrows / borrowPool * IOracle(oracle).getLatestPrice(token);
        if(borrow[_user] == 0) {
            _collateral = int(collateralValue) * int(loanToValue) / int(ACCURACY); 
        } else {
            _collateral = (int(collateralValue) * int(loanToValue) - int(borrowsValue) * int(ACCURACY)) / int(ACCURACY);
        }
    }

    function _checkOverLTVPotentialDecreaseCollateral_(
        address _user, 
        uint _collateralAmount, 
        uint _decreaseCollateral
    )
        public view returns(int _collateral)
    {
        uint _totalBorrows = preUpdateTotalBorrows();
        uint collateralValue = (_collateralAmount - _decreaseCollateral) * IOracle(oracle).getLatestPrice(token);
        if (borrow[_user] == 0){
            _collateral = int(collateralValue);
        } else {
            uint borrowsValue = borrow[_user] * _totalBorrows / borrowPool * IOracle(oracle).getLatestPrice(token);
            _collateral = (int(collateralValue) * int(loanToValue) - int(borrowsValue) * int(ACCURACY)) / int(ACCURACY);
        }   
    }

    function _checkOverLTVPotentialIncreaseBorrow_(
        address _user, 
        uint _collateralAmount, 
        uint _increaseBorrow
    )
        public view returns(int _collateral)
    {
        uint _totalBorrows = preUpdateTotalBorrows();
        uint _potentialIncreaseShare = _calculateNewBorrowPool(_increaseBorrow) - borrowPool;
        uint borrowsValue = 
        (borrow[_user] + _potentialIncreaseShare) * (_totalBorrows + _increaseBorrow) * IOracle(oracle).getLatestPrice(token) / _calculateNewBorrowPool(_increaseBorrow);
        if (_collateralAmount == 0){
            _collateral = - int(borrowsValue);
        } else {
            uint collateralValue = _collateralAmount * IOracle(oracle).getLatestPrice(token);
            _collateral = ((int(collateralValue) * int(loanToValue)) - (int(borrowsValue) * int(ACCURACY))) / int(ACCURACY);
        }   
    }

    function _calculateActualBorrowRate()internal view returns(uint _borrowRate){
        if(kink > IOperator(marketOperator).utilizationRate()){
            if(IOperator(marketOperator).utilizationRate() >= 1000){
                return _borrowRate = baseBorrowRatePerYear * IOperator(marketOperator).utilizationRate() / 1000;
            } else {
                return _borrowRate = baseBorrowRatePerYear;
            } 
        } else {
            if (DIV * DIV > IOperator(marketOperator).utilizationRate()){
                return _borrowRate = borrowRatePerYearMultiplier * IOperator(marketOperator).utilizationRate() / DIV - mathCoefficient;
            } else {
                return _borrowRate = ultimateBorrowRatePerYear;
            } 
        }   
    }

    function _calculateNewBorrowPool(uint _amount)internal view returns(uint _newPool){
        return borrowPool * ACCURACY / (ACCURACY - (_amount * ACCURACY / (totalBorrows + _amount)));
    } 

    function _calculateUserDebt(address _user)internal view returns(uint _debt){
        return borrow[_user] * totalBorrows / borrowPool;
    }
}

contract BorrowFactory is AccessControl { 

    address public immutable operatorFactory;
    address public immutable oracle;

    mapping(address => bool) public borrowCoreExist;

    constructor(address _oracle, address _operatorFactory){
        oracle = _oracle;
        operatorFactory = _operatorFactory;
        _setupRole(DEFAULT_CALLER, operatorFactory);
    }

    function setupRole(address marketOperator)external onlyRole(DEFAULT_CALLER){
        _setupRole(DEFAULT_CALLER, marketOperator);
    }

    function createBorrowCore(
        address token, 
        address marketOperator, 
        uint _baseBorrowRatePerYear, 
        uint _borrowRatePerYearMultiplier, 
        uint _ultimateBorrowRatePerYear, 
        uint _mathCoefficient,
        uint _kink,
        uint _loanToValue,  
        uint _liquidationThreshold
    )
        external 
        onlyRole(DEFAULT_CALLER) 
        returns(address)
    {
        require(borrowCoreExist[token] == false, "BorrowFactory: Invalid create");
        BorrowCore _core = new BorrowCore(
            token, 
            marketOperator, 
            oracle, 
            _baseBorrowRatePerYear,
            _borrowRatePerYearMultiplier, 
            _ultimateBorrowRatePerYear, 
            _mathCoefficient,
            _kink, 
            _loanToValue, 
            _liquidationThreshold
        );
        borrowCoreExist[token] = true;

        return address(_core);
    }
}
