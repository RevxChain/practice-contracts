// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "./access/AccessControl.sol";
import "./interfaces/IOperator.sol";
import "./interfaces/ISupply.sol";
import "./interfaces/IBorrow.sol";
import "./interfaces/ICollateral.sol";

contract MarketOperator is AccessControl {

    uint public constant DIV = 100;
    uint public constant ACCURACY = 1e18;
    uint public constant EMERGENCY_UTILIZATION_RATE = 9700;

    address public supplyCore;
    address public borrowCore;
    address public collateralCore;

    address public immutable token;
    address public immutable protocol;

    event EmergencyReplenishment(uint amountToReplenish, uint time);
    event ActualIndex(uint totalLiquidity, uint utilizationRate, uint time);

    constructor(
        address _token, 
        address _protocol
    )
    {
        token = _token;
        protocol = _protocol;  
        _setupRole(DEFAULT_CALLER, protocol);
        _setupRole(DEFAULT_CALLER, msg.sender);
    }

    function initialize(        
        address _supplyFactory, 
        address _borrowFactory, 
        address _collateralFactory,
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
    {   
        require(supplyCore == address(0) && borrowCore == address(0) && collateralCore == address(0), "Operator: Invalid initialize");
        supplyCore = ISupplyFactory(_supplyFactory).createSToken(token, address(this));
        borrowCore = IBorrowFactory(_borrowFactory).createBorrowCore(
            token, 
            address(this), 
            _baseBorrowRatePerYear,
            _borrowRatePerYearMultiplier,
            _ultimateBorrowRatePerYear,
            _mathCoefficient,
            _kink,  
            _loanToValue, 
            _liquidationThreshold
        ); 
        collateralCore = ICollateralFactory(_collateralFactory).createSafe(token, address(this));
    }

    function _addSupply(address _user, uint _underlyingAmount)external onlyRole(DEFAULT_CALLER){
        ISupply(supplyCore)._addSupply_(_user, _underlyingAmount, totalLiquidity());

        emit ActualIndex(totalLiquidity(), utilizationRate(), block.timestamp);
    }

    function _withdrawSupply(address _user, uint _amount)external onlyRole(DEFAULT_CALLER) returns(uint _underlyingAmount){ 
        _underlyingAmount = ISupply(supplyCore)._withdrawSupply_(_user, _amount, totalLiquidity());
        _emergencyReplenishment();

        emit ActualIndex(totalLiquidity(), utilizationRate(), block.timestamp);
    }

    function _addCollateral(address _user, uint _underlyingAmount)external onlyRole(DEFAULT_CALLER) returns(address){
        ICollateral(collateralCore)._addCollateral_(_user, _underlyingAmount);
        return collateralCore;
    }

    function _convertSupplyToCollateral(address _user, uint _sTokensAmount)external onlyRole(DEFAULT_CALLER) returns(uint _underlyingAmount){
        _underlyingAmount =  ISupply(supplyCore)._convertSupplyToCollateral_(_user, collateralCore, _sTokensAmount, totalLiquidity());
        ICollateral(collateralCore)._addCollateral_(_user, _underlyingAmount);
        _emergencyReplenishment();

        emit ActualIndex(totalLiquidity(), utilizationRate(), block.timestamp);
    }

    function _withdrawCollateral(address _user, uint _underlyingAmount)external onlyRole(DEFAULT_CALLER){
        uint _collateralAmount = ICollateral(collateralCore).collateralAmount(_user);
        require(_collateralAmount >= _underlyingAmount, "Operator: Not enough collateral to withdraw");
        ICollateral(collateralCore)._withdrawCollateral_(_user, _user, _underlyingAmount);
    }

    function _convertCollateralToSupply(address _user, uint _underlyingAmount)external onlyRole(DEFAULT_CALLER){
        uint _collateralAmount = ICollateral(collateralCore).collateralAmount(_user);
        require(_collateralAmount >= _underlyingAmount, "Operator: Not enough collateral to convert");
        ICollateral(collateralCore)._withdrawCollateral_(_user, supplyCore, _underlyingAmount);
        ISupply(supplyCore)._addSupply_(_user, _underlyingAmount, totalLiquidity());

        emit ActualIndex(totalLiquidity(), utilizationRate(), block.timestamp);
    }

    function _borrow(address _user, uint _underlyingAmount)external onlyRole(DEFAULT_CALLER){
        IBorrow(borrowCore)._borrow_(_user, _underlyingAmount);
        ISupply(supplyCore)._borrow_(_user, _underlyingAmount);
        _emergencyReplenishment();

        emit ActualIndex(totalLiquidity(), utilizationRate(), block.timestamp);
    }
    
    function _redeem(address _user, uint _underlyingAmount)external onlyRole(DEFAULT_CALLER){
        IBorrow(borrowCore)._redeem_(_user, _underlyingAmount);   
        ISupply(supplyCore)._redeem_(_underlyingAmount);

        emit ActualIndex(totalLiquidity(), utilizationRate(), block.timestamp);
    }

    function _liquidate(address _user, address _liquidator, uint _rate)external onlyRole(DEFAULT_CALLER) returns(address, uint _debt){
        uint _borrowShare = IBorrow(borrowCore).borrow(_user);
        if(_borrowShare > 0){
            _debt = IBorrow(borrowCore)._liquidate_(_user, _liquidator);
        }
        uint _collateralAmount = ICollateral(collateralCore).collateralAmount(_user);
        uint amountToSupply; 
        if(_collateralAmount > 0){
            if(ACCURACY > _rate){
                amountToSupply = ICollateral(collateralCore)._partialBuyout_(_user, _liquidator, supplyCore, _rate);

            } else {
                ICollateral(collateralCore)._fullBuyout_(_user, _liquidator);
            }
        }
        if(_debt + amountToSupply > 0){
            ISupply(supplyCore)._redeem_(_debt + amountToSupply);
        }

        emit ActualIndex(totalLiquidity(), utilizationRate(), block.timestamp);

        return (token, _debt);
    }

    function _serviceLiquidate(address _user)external onlyRole(DEFAULT_CALLER){
        uint _borrowShare = IBorrow(borrowCore).borrow(_user);
        uint _debt;
        if(_borrowShare > 0){
            uint _reserve = ICollateral(collateralCore).reserve();
            _debt = IBorrow(borrowCore)._serviceLiquidate_(_user, _reserve);
        }
        uint _collateralAmount = ICollateral(collateralCore).collateralAmount(_user);
        if(_collateralAmount > 0 || _borrowShare > 0){
            ICollateral(collateralCore)._serviceLiquidate_(_user, supplyCore, _debt);
        }
        if(_debt + _collateralAmount > 0){
            ISupply(supplyCore)._redeem_(_debt + _collateralAmount);
        }

        emit ActualIndex(totalLiquidity(), utilizationRate(), block.timestamp);
    }

    function _emergencyReplenishment()internal {
        if(utilizationRate() >= EMERGENCY_UTILIZATION_RATE){
            uint _totalSupply = ISupply(supplyCore).supply();
            uint _amountToReplenish = ICollateral(collateralCore)._emergencyReplenishment_(supplyCore, _totalSupply);
            ISupply(supplyCore)._redeem_(_amountToReplenish);

            emit EmergencyReplenishment(_amountToReplenish, block.timestamp);
        }
    }

    function _checkOverCollateralRate(address _user)external view returns(int _balance, uint _collateralValue, uint _borrowValue){
        uint _collateralAmount = ICollateral(collateralCore).collateralAmount(_user);

        return IBorrow(borrowCore)._checkOverCollateralRate_(_user, _collateralAmount);
    }

    function _checkOverLTV(address _user)external view returns(int _collateral){
        uint _collateralAmount = ICollateral(collateralCore).collateralAmount(_user);

        return IBorrow(borrowCore)._checkOverLTV_(_user, _collateralAmount);
    } 
    
    function _checkOverLTVPotentialDecreaseCollateral(address _user, uint _decreaseCollateral)external view returns(int _collateral){
        uint _collateralAmount = ICollateral(collateralCore).collateralAmount(_user);

        return IBorrow(borrowCore)._checkOverLTVPotentialDecreaseCollateral_(_user, _collateralAmount, _decreaseCollateral);
    }

    function _checkOverLTVPotentialIncreaseBorrow(address _user, uint _increaseBorrow)external view returns(int _collateral){
        uint _collateralAmount = ICollateral(collateralCore).collateralAmount(_user);

        return IBorrow(borrowCore)._checkOverLTVPotentialIncreaseBorrow_(_user, _collateralAmount, _increaseBorrow);
    }
    
    function totalLiquidity()public view returns(uint){
        return ISupply(supplyCore).supply() + IBorrow(borrowCore).totalBorrows();
    }

    function utilizationRate()public view returns(uint _utilizationRate){
        return IBorrow(borrowCore).totalBorrows() * DIV * DIV / totalLiquidity();
    }
}

contract OperatorFactory is AccessControl { 

    address public supplyFactory;
    address public borrowFactory;
    address public collateralFactory;
    
    address public immutable protocol;

    bytes32 public constant DISPOSABLE_CALLER = keccak256(abi.encode("DISPOSABLE_CALLER"));
                            
    mapping(address => address) public operator;

    address[] public allOperators;

    constructor(address _protocol){
        _setupRole(DEFAULT_CALLER, _protocol);
        _setupRole(DISPOSABLE_CALLER, tx.origin);
        protocol = _protocol;
    }

    function setFactoryAddressses(
        address _supplyFactory, 
        address _borrowFactory, 
        address _collateralFactory
    )
        external 
        onlyRole(DISPOSABLE_CALLER)
    {
        require (supplyFactory == address(0) && borrowFactory == address(0) && collateralFactory == address(0), "OperatorFactory: 0x00");
        supplyFactory = _supplyFactory;
        borrowFactory = _borrowFactory;
        collateralFactory = _collateralFactory;
    }

    function createMarket(
        address token,
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
        returns(address _address)
    {
        require(operator[token] == address(0), "OperatorFactory: Market is exist already");
        MarketOperator _market = new MarketOperator(token, protocol);
        _address = address(_market); 
        ISupplyFactory(supplyFactory).setupRole(_address);
        IBorrowFactory(borrowFactory).setupRole(_address);
        ICollateralFactory(collateralFactory).setupRole(_address);
        IOperator(_address).initialize(
            supplyFactory, 
            borrowFactory, 
            collateralFactory,
            _baseBorrowRatePerYear,
            _borrowRatePerYearMultiplier,
            _ultimateBorrowRatePerYear,
            _mathCoefficient,
            _kink, 
            _loanToValue, 
            _liquidationThreshold
        );
        operator[token] = _address; 
        allOperators.push(_address);
    } 

    function coreAddresses(address _token)
        external 
        view 
        returns(
            address _operator, 
            address _supplyCore, 
            address _borrowCore, 
            address _collateralCore
        )
    {
        _operator = operator[_token];
        _supplyCore = IOperator(_operator).supplyCore();
        _borrowCore = IOperator(_operator).borrowCore();
        _collateralCore = IOperator(_operator).collateralCore();
    }   
}
