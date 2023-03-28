// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "./access/AccessControl.sol";

contract sToken is ERC20, AccessControl, ERC20Burnable {
    using SafeERC20 for IERC20;

    uint public supply; 

    uint public constant ONE_YEAR_DURATION = 52 weeks; 
    uint public constant ACCURACY = 1e18;
    uint public constant DIV = 100;
    uint public constant FIRST_LOCK_VALUE = 10000; 

    address public immutable token;
    address public immutable marketOperator;
    address public immutable oracle;

    event ActualSupply(uint supply, uint time);

    constructor(address _token, address _marketOperator, address _oracle) ERC20("sToken","sToken"){
        token = _token;
        marketOperator = _marketOperator;
        oracle = _oracle;
        _setupRole(DEFAULT_CALLER, marketOperator);
    }

    function _addSupply_(address _user, uint _underlyingAmount, uint _totalLiquidity)external onlyRole(DEFAULT_CALLER){
        uint newPool;
        uint userShare;
        if(totalSupply() == 0){
            (newPool, userShare) = _firstAddSupply_(_underlyingAmount);
        } else {
            newPool = totalSupply() * ACCURACY / (ACCURACY - (_underlyingAmount * ACCURACY / (_totalLiquidity + _underlyingAmount)));
            userShare = newPool - totalSupply();
        }
        _mint(_user, userShare);
        supply += _underlyingAmount;

        emit ActualSupply(supply, block.timestamp);
    }
    
    function _withdrawSupply_(
        address _user, 
        uint _sTokensAmount, 
        uint _totalLiquidity
    )
        external 
        onlyRole(DEFAULT_CALLER) 
        returns(uint _underlyingAmount)
    {
        require(balanceOf(_user) >= _sTokensAmount, "sToken: Not enough sTokens");
        _underlyingAmount = _sTokensAmount * _totalLiquidity / totalSupply();
        require(supply >= _underlyingAmount, "sToken: Not enough underlying tokens in supply");
        _burn(_user, _sTokensAmount);
        supply -= _underlyingAmount;
        IERC20(token).safeTransfer(_user, _underlyingAmount);

        emit ActualSupply(supply, block.timestamp);
    }

    function _convertSupplyToCollateral_(
        address _user, 
        address _collateralCore, 
        uint _sTokensAmount, 
        uint _totalLiquidity
    )
        external 
        onlyRole(DEFAULT_CALLER) 
        returns(uint _underlyingAmount)
    {
        require(balanceOf(_user) >= _sTokensAmount, "sToken: Not enough sTokens");
        _underlyingAmount = _sTokensAmount * _totalLiquidity / totalSupply(); 
        require(supply > _underlyingAmount, "sToken: Not enough underlying tokens in supply");
        _burn(_user, _sTokensAmount);
        supply -= _underlyingAmount;
        IERC20(token).safeTransfer(_collateralCore, _underlyingAmount);

        emit ActualSupply(supply, block.timestamp);
    }

    function _borrow_(address _user, uint _underlyingAmount)external onlyRole(DEFAULT_CALLER){
        require(supply > _underlyingAmount, "sToken: Not enough underlying tokens in supply");
        supply -= _underlyingAmount; 
        IERC20(token).safeTransfer(_user, _underlyingAmount);

        emit ActualSupply(supply, block.timestamp);
    }

    function _redeem_(uint _underlyingAmount)external onlyRole(DEFAULT_CALLER){
        supply += _underlyingAmount; 

        emit ActualSupply(supply, block.timestamp);
    }

    function _updateSupply()external onlyRole(DEFAULT_CALLER){ 
        if(IERC20(token).balanceOf(address(this)) > supply){
            supply = IERC20(token).balanceOf(address(this));

            emit ActualSupply(supply, block.timestamp);
        }
    }

    function _firstAddSupply_(uint _underlyingAmount)internal returns(uint newPool, uint userShare){
        userShare = _underlyingAmount / 10;
        newPool = userShare + FIRST_LOCK_VALUE;
        _mint(marketOperator, FIRST_LOCK_VALUE);   
    }
}

contract SupplyFactory is AccessControl { 

    address immutable operatorFactory;
    address immutable oracle;

    mapping(address => bool) public sTokenExist;

    constructor(address _oracle, address _operatorFactory){
        oracle = _oracle;
        operatorFactory = _operatorFactory;
        _setupRole(DEFAULT_CALLER, operatorFactory);
    }

    function setupRole(address marketOperator)external onlyRole(DEFAULT_CALLER){
        _setupRole(DEFAULT_CALLER, marketOperator);
    }

    function createSToken(address token, address marketOperator)external onlyRole(DEFAULT_CALLER) returns(address){
        require(sTokenExist[token] == false, "SupplyFactory: Invalid create");
        sToken _core = new sToken(token, marketOperator, oracle);
        sTokenExist[token] = true;

        return address(_core);
    } 
}
