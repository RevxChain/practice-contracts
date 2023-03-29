// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./access/AccessControl.sol";
import "./interfaces/IOperator.sol";

contract Protocol is AccessControl, ReentrancyGuard{
    using SafeERC20 for IERC20;

    uint public constant ACCURACY = 1e18;

    address public operatorFactory;

    bytes32 public constant PROTOCOL_MANAGEMENT = keccak256(abi.encode("PROTOCOL_MANAGEMENT"));

    mapping(address => bool) public onlyCollateral; 
    mapping(address => address) public marketOperator; 
    mapping(address => address[]) public usingMarkets; 
    mapping(address => bool) public marketOperatorExistence; 
    mapping(address => mapping(address => bool)) public usingMarket;

    event MarketCreated(address token, uint time, bool indexed onlyCollateral);
    event MarketOpenedToLend(address token, uint time);
    event UserAddSupply(address indexed user, address indexed token, uint underlyingAmount, uint time);
    event UserWithdrawSupply(address indexed user, address indexed token, uint underlyingAmount, uint time);
    event UserAddCollateral(address indexed user, address indexed token, uint underlyingAmount, uint time);
    event UserWithdrawCollateral(address indexed user, address indexed token, uint underlyingAmount, uint time);
    event UserBorrow(address indexed user, address indexed token, uint underlyingAmount, uint time);
    event UserRedeem(address indexed user, address indexed token, uint underlyingAmount, uint time);
    event UserLiquidated(address indexed user, address indexed liquidator, uint userBorrow, uint userCollateral, uint time);
    event UserLiquidatedByProtocol(address indexed _user, uint time);
    event UserLiquidatable(address indexed _user, uint userBorrow, uint userCollateral, uint time);

    modifier marketExist(address _token){
        require(marketOperatorExistence[_token] == true && marketOperator[_token] != address(0), "Lending: Market is not exist");
        _;
    }
    
    modifier openToLend(address _token){
        require(onlyCollateral[_token] == false, "Lending: Only collateral market"); 
        _;
    }

    modifier validUnderlyingAmount(uint _amount){
        require(_amount >= ACCURACY, "Lending: Invalid underlying amount"); 
        _;
    }

    modifier validSTokensAmount(uint _amount){
        require(_amount >= ACCURACY / 10, "Lending: Invalid sTokens amount"); 
        _;
    }

    constructor(){
        _setupRole(PROTOCOL_MANAGEMENT, tx.origin); 
    }

    function setOperatorFactoryAddress(address _operatorFactory)external onlyRole(PROTOCOL_MANAGEMENT){
        require(operatorFactory == address(0), "Lending: Set already");
        operatorFactory = _operatorFactory;
    }
    
    function createMarket(
        address _token, 
        uint _baseBorrowRatePerYear,
        uint _borrowRatePerYearMultiplier,
        uint _ultimateBorrowRatePerYear,
        uint _mathCoefficient,
        uint _kink, 
        uint _loanToValue, 
        uint _liquidationThreshold,
        bool _onlyCollateral
    )
        external 
        onlyRole(PROTOCOL_MANAGEMENT)
        returns(address marketOperatorAddress)
    {
        require(marketOperator[_token] == address(0), "Lending: Market is exist already");
        marketOperatorAddress = IOperatorFactory(operatorFactory).createMarket(
            _token, 
            _baseBorrowRatePerYear,
            _borrowRatePerYearMultiplier,
            _ultimateBorrowRatePerYear,
            _mathCoefficient,
            _kink, 
            _loanToValue,  
            _liquidationThreshold
        );
        marketOperator[_token] = marketOperatorAddress;
        marketOperatorExistence[_token] = true;
        onlyCollateral[_token] = _onlyCollateral;

        emit MarketCreated(_token, block.timestamp, _onlyCollateral);
    }

    function openMarketToLend(address _token)external marketExist(_token) onlyRole(PROTOCOL_MANAGEMENT){
        require(onlyCollateral[_token] == true, "Lending: Only collateral market"); 
        onlyCollateral[_token] = false;

        emit MarketOpenedToLend(_token, block.timestamp);
    }

    function addSupply(address _token, uint _underlyingAmount)
        external 
        marketExist(_token) 
        openToLend(_token)  
        validUnderlyingAmount(_underlyingAmount)
        nonReentrant()
    {
        (address _user, address _marketOperator) = defineData(_token);
        balanceCheck(_user, _token, _underlyingAmount);
        IOperator(_marketOperator)._addSupply(_user, _underlyingAmount);
        address _supplyCoreAddress = IOperator(_marketOperator).supplyCore();
        IERC20(_token).safeTransferFrom(_user, _supplyCoreAddress, _underlyingAmount);

        emit UserAddSupply(_user, _token, _underlyingAmount, block.timestamp);
    }

    function withdrawSupply(address _token, uint _sTokensAmount)
        external 
        marketExist(_token) 
        openToLend(_token)  
        validSTokensAmount(_sTokensAmount)
        nonReentrant()
    {
        (address _user, address _marketOperator) = defineData(_token);
        uint _underlyingAmount = IOperator(_marketOperator)._withdrawSupply(_user, _sTokensAmount);

        emit UserWithdrawSupply(_user, _token, _underlyingAmount, block.timestamp);
    }

    function addCollateral(address _token, uint _underlyingAmount)
        external 
        marketExist(_token)  
        validUnderlyingAmount(_underlyingAmount)
        nonReentrant()
    {
        (address _user, address _marketOperator) = defineData(_token);
        balanceCheck(_user, _token, _underlyingAmount);
        addToList(_user, _marketOperator);
        address _collateralCoreAddress = IOperator(_marketOperator)._addCollateral(_user, _underlyingAmount);
        IERC20(_token).safeTransferFrom(_user, _collateralCoreAddress, _underlyingAmount);

        emit UserAddCollateral(_user, _token, _underlyingAmount, block.timestamp);
    }

    function convertSupplyToCollateral(address _token, uint _sTokensAmount)
        external 
        marketExist(_token) 
        openToLend(_token) 
        validSTokensAmount(_sTokensAmount)
        nonReentrant() 
    {
        (address _user, address _marketOperator) = defineData(_token);
        addToList(_user, _marketOperator);
        uint _underlyingAmount = IOperator(_marketOperator)._convertSupplyToCollateral(_user, _sTokensAmount);      

        emit UserWithdrawSupply(_user, _token, _underlyingAmount, block.timestamp);
        emit UserAddCollateral(_user, _token, _underlyingAmount, block.timestamp);
    } 
    
    function withdrawCollateral(address _token, uint _underlyingAmount)
        external 
        marketExist(_token)  
        validUnderlyingAmount(_underlyingAmount)
        nonReentrant()
    {
        (address _user, address _marketOperator) = defineData(_token);
        involvedMarketCheck(_user, _marketOperator);
        liquidatableRevert(_user);
        decreaseCollateralCheck(_user, _token, _underlyingAmount);
        IOperator(_marketOperator)._withdrawCollateral(_user, _underlyingAmount); 

        emit UserWithdrawCollateral(_user, _token, _underlyingAmount, block.timestamp);
    }

    function convertCollateralToSupply(address _token, uint _underlyingAmount)
        external 
        marketExist(_token)  
        openToLend(_token) 
        validUnderlyingAmount(_underlyingAmount)
        nonReentrant()
    {
        (address _user, address _marketOperator) = defineData(_token);
        involvedMarketCheck(_user, _marketOperator);
        liquidatableRevert(_user); 
        decreaseCollateralCheck(_user, _token, _underlyingAmount);
        IOperator(_marketOperator)._convertCollateralToSupply(_user, _underlyingAmount);

        emit UserWithdrawCollateral(_user, _token, _underlyingAmount, block.timestamp);
        emit UserAddSupply(_user, _token, _underlyingAmount, block.timestamp);
    } 
    
    function borrow(address _token, uint _underlyingAmount)
        external 
        marketExist(_token)  
        openToLend(_token) 
        validUnderlyingAmount(_underlyingAmount)
        nonReentrant()
    { 
        (address _user, address _marketOperator) = defineData(_token);
        addToList(_user, _marketOperator);
        liquidatableRevert(_user); 
        (bool uncovered, ) = checkOverLTVPotentialIncreaseBorrow(_user, _token, _underlyingAmount);
        require(uncovered == false, "Lending: You can not borrow");
        IOperator(_marketOperator)._borrow(_user, _underlyingAmount);

        emit UserBorrow(_user, _token, _underlyingAmount, block.timestamp);
    }
    
    function redeem(address _token, uint _underlyingAmount)
        external 
        marketExist(_token)  
        openToLend(_token) 
        validUnderlyingAmount(_underlyingAmount)
        nonReentrant()
    {
        (address _user, address _marketOperator) = defineData(_token);
        involvedMarketCheck(_user, _marketOperator);
        balanceCheck(_user, _token, _underlyingAmount);
        liquidatableRevert(_user);
        IOperator(_marketOperator)._redeem(_user, _underlyingAmount);
        IERC20(_token).safeTransferFrom(_user, IOperator(_marketOperator).supplyCore(), _underlyingAmount);

        emit UserRedeem(_user, _token, _underlyingAmount, block.timestamp);
    } 

    function liquidate(address _user)external nonReentrant(){
        involveVerify(_user);
        address _liquidator = msg.sender;
        (uint _totalCollateralValue, uint _totalBorrowValue) = liquidatableAllow(_user);
        uint _rate = _totalBorrowValue * ACCURACY / _totalCollateralValue;
        for (uint i; i < usingMarkets[_user].length; i++){
            (address _token, uint _debt) = IOperator(usingMarkets[_user][i])._liquidate(_user, _liquidator, _rate); 
            if(_debt > 0){
                IERC20(_token).safeTransferFrom(_liquidator, IOperator(usingMarkets[_user][i]).supplyCore(), _debt);
            }
            usingMarket[_user][usingMarkets[_user][i]] = false;
        }
        delete usingMarkets[_user];

        emit UserLiquidated(_user, _liquidator, _totalBorrowValue, _totalCollateralValue, block.timestamp);
    }

    function serviceLiquidate(address _user)external onlyRole(PROTOCOL_MANAGEMENT) nonReentrant(){
        involveVerify(_user);
        liquidatableAllow(_user);
        for (uint i; i < usingMarkets[_user].length; i++){
            IOperator(usingMarkets[_user][i])._serviceLiquidate(_user); 
            usingMarket[_user][usingMarkets[_user][i]] = false;
        }
        delete usingMarkets[_user];

        emit UserLiquidatedByProtocol(_user, block.timestamp);
    }
    
    function liquidateCall(address _user)external nonReentrant(){
        involveVerify(_user);
        (uint _totalCollateralValue, uint _totalBorrowValue) = liquidatableAllow(_user);

        emit UserLiquidatable(_user, _totalBorrowValue, _totalCollateralValue, block.timestamp);
    }

    function checkLiquidationPossibility(address _user)
        public 
        view 
        returns(
            bool uncovered, 
            int _totalBalance, 
            uint _totalCollateralValue, 
            uint _totalBorrowValue
        )
    {
        involveVerify(_user);
        for (uint i; i < usingMarkets[_user].length; i++){
            (int _balance, uint _collateralValue, uint _borrowValue) = 
            IOperator(usingMarkets[_user][i])._checkOverCollateralRate(_user);
            _totalBalance += _balance;
            _totalCollateralValue += _collateralValue;
            _totalBorrowValue += _borrowValue;
        }
        if(0 >= _totalBalance){
            uncovered = true;
        } 
    }

    function checkOverLTV(address _user)public view returns(bool LTVExceed, int _totalCollateral){
        involveVerify(_user); 
        for (uint i; i < usingMarkets[_user].length; i++){
            int _collateral = IOperator(usingMarkets[_user][i])._checkOverLTV(_user);
            _totalCollateral += _collateral;
        }
        if(0 >= _totalCollateral){
            LTVExceed = true;
        } 
    }

    function checkOverLTVPotentialDecreaseCollateral(
        address _user, 
        address _token, 
        uint _decreaseCollateral
    )
        public 
        view 
        returns(
            bool LTVExceed, 
            int _totalCollateral
        )
    {
        involveVerify(_user);
        address _marketOperator = marketOperator[_token];
        for (uint i; i < usingMarkets[_user].length; i++){
            int _collateral;
            if(_marketOperator != usingMarkets[_user][i]){
                _collateral = IOperator(usingMarkets[_user][i])._checkOverLTV(_user);
            } else {
                _collateral = IOperator(usingMarkets[_user][i])._checkOverLTVPotentialDecreaseCollateral(_user, _decreaseCollateral);
            }
            _totalCollateral += _collateral;
        }
        if(0 >= _totalCollateral){
            LTVExceed = true;
        }
    }

    function checkOverLTVPotentialIncreaseBorrow(
        address _user, 
        address _token, 
        uint _increaseBorrow
    )
        public 
        view 
        returns(
            bool LTVExceed, 
            int _totalCollateral
        )
    {
        involveVerify(_user);
        address _marketOperator = marketOperator[_token];
        for (uint i; i < usingMarkets[_user].length; i++){
            int _collateral;
            if(_marketOperator != usingMarkets[_user][i]){
                _collateral = IOperator(usingMarkets[_user][i])._checkOverLTV(_user);
            } else {
                _collateral = IOperator(usingMarkets[_user][i])._checkOverLTVPotentialIncreaseBorrow(_user, _increaseBorrow);
            }
            _totalCollateral += _collateral;
        }
        if(0 >= _totalCollateral){
            LTVExceed = true;
        }
    }

    function addToList(address _user, address _marketOperator)internal {
        if(usingMarket[_user][_marketOperator] == false){
            usingMarkets[_user].push(_marketOperator);
            usingMarket[_user][_marketOperator] = true;
        }
    }

    function involveVerify(address _user)internal view {
        require(usingMarkets[_user].length > 0, "Lending: Invalid call");
    } 

    function defineData(address _token)internal view returns(address _user, address _marketOperator){
        _user = msg.sender;
        _marketOperator = marketOperator[_token];
    }

    function liquidatableRevert(address _user)internal view{
        (bool uncovered, , , ) = checkLiquidationPossibility(_user);
        require(uncovered == false, "Lending: Your positions should be liquidated"); 
    }
    
    function liquidatableAllow(address _user)internal view returns(uint, uint){
        (bool uncovered, , uint totalCollateralValue, uint totalBorrowValue) = checkLiquidationPossibility(_user);
        require(uncovered == true, "Lending: This user can not be liquidated");

        return (totalCollateralValue, totalBorrowValue);
    }

    function balanceCheck(address _user, address _token, uint _underlyingAmount)internal view {
        require(IERC20(_token).balanceOf(_user) >= _underlyingAmount, "Lending: Not enough underlying tokens");
    }

    function involvedMarketCheck(address _user, address _marketOperator)internal view {
        require(usingMarket[_user][_marketOperator] == true, "Lending: You have not got that underlying collateral");
    }

    function decreaseCollateralCheck(address _user, address _token, uint _underlyingAmount)internal view{
        (bool uncovered, ) = checkOverLTVPotentialDecreaseCollateral(_user, _token, _underlyingAmount);
        require(uncovered == false, "Lending: Not enough collateral");
    }
}
