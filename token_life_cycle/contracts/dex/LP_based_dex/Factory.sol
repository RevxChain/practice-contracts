// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";

contract ERC20Pair is ERC20, AccessControl, ERC20Burnable {
    using SafeERC20 for IERC20;

    uint public reserve0;
    uint public reserve1;
    uint public k;

    uint private constant MINIMUM_LIQUIDITY_TO_ADD = 100000;
    uint private constant MINIMUM_LIQUIDITY_TO_LOCK = 10000;

    address public immutable factory;
    address public immutable router;
    address public immutable token0;
    address public immutable token1;

    constructor(address _token0, address _token1, address _router) ERC20("LPToken","LPT"){
        factory = msg.sender;
        router = _router;
        _setupRole(DEFAULT_ADMIN_ROLE, router);
        token0 = _token0;
        token1 = _token1;
    }

    function _swap(address _tokenIn, uint _amountIn, address _to)external onlyRole(DEFAULT_ADMIN_ROLE) returns(uint amountOut){
        if (_tokenIn == token0){
            uint newReserve1 = k / (reserve0 + _amountIn);
            amountOut = reserve1 - newReserve1;
            reserve0 += _amountIn;
            reserve1 -= amountOut;
            IERC20(token1).safeTransfer(_to, amountOut);
        } else {
            uint newReserve0 = k / (reserve1 + _amountIn);
            amountOut = reserve0 - newReserve0;
            reserve0 -= amountOut;
            reserve1 += _amountIn;
            IERC20(token0).safeTransfer(_to, amountOut);
        }
    }

    function _lpMint(address _user, uint _amount0, uint _amount1)external onlyRole(DEFAULT_ADMIN_ROLE) returns(uint ,uint){
        uint _totalSupply = totalSupply();
        if (_totalSupply == 0){
            _firstAddLiquidity(_user, _amount0, _amount1);
            _mint(factory, MINIMUM_LIQUIDITY_TO_LOCK);
        } else {    
            uint _nAmount1 = reserve1 * _amount0 / reserve0;
            if(_amount1 < _nAmount1){
                _amount0 = reserve0 * _amount1 / reserve1;
            } else {
                _amount1 = _nAmount1;
            }
            uint _lpTokens = _amount0 * _totalSupply / reserve0;
            require(_lpTokens > MINIMUM_LIQUIDITY_TO_ADD, "Pair: Insufficient LP tokens amount");
            _mint(_user, _lpTokens);

            reserve0 += _amount0;
            reserve1 += _amount1;
            k = reserve0 * reserve1;         
        }   

        return (_amount0, _amount1);   
    }

    function _lpBurn(address _user, uint _amount)external onlyRole(DEFAULT_ADMIN_ROLE) returns(uint _amount0, uint _amount1){
        uint _totalSupply = totalSupply();
        _amount0 = _amount * reserve0 / _totalSupply;
        _amount1 = _amount * reserve1 / _totalSupply;
        reserve0 -= _amount0;
        reserve1 -= _amount1;
        k = reserve0 * reserve1;
        _burn(_user, _amount);
        IERC20(token0).approve(msg.sender, _amount0);
        IERC20(token1).approve(msg.sender, _amount1);
    }

    function _updateReserves()external {
        uint balance0 = IERC20(token0).balanceOf(address(this)); 
        uint balance1 = IERC20(token1).balanceOf(address(this));
        uint f = 2**256 - 1;
        require((balance0 <= f) && (balance1 <= f), "Pair: Overflow");
        reserve0 = balance0;
        reserve1 = balance1;
        k = reserve0 * reserve1;
    }

    function getReserves()external view returns (uint _reserve0, uint _reserve1){
        _reserve0 = reserve0;
        _reserve1 = reserve1;
    }

    function burn(uint256 amount)public override onlyRole(DEFAULT_ADMIN_ROLE){
        super.burn(amount);
    }

    function burnFrom(address account, uint256 amount)public override onlyRole(DEFAULT_ADMIN_ROLE){
        super.burnFrom(account, amount);
    }

    function _firstAddLiquidity(address _user, uint _amount0, uint _amount1)internal {
        k = _amount0 * _amount1;
        reserve0 = _amount0;
        reserve1 = _amount1;
        _mint(_user, _amount0 + _amount1);
    }
}

contract Factory is AccessControl { 

    mapping(address => mapping(address => address)) public pair;

    address public router;
    address[] public allPairs;

    bytes32 public constant DISPOSABLE_CALLER = keccak256(abi.encode("DISPOSABLE_CALLER"));

    constructor(){
        _setupRole(DISPOSABLE_CALLER, tx.origin);
    }

    function setupRouter(address _router)external onlyRole(DISPOSABLE_CALLER){
        require(router == address(0), "Factory: 0x01");
        router = _router;
        _setupRole(DEFAULT_ADMIN_ROLE, router);
    }

    function createPair(address token0, address token1) external onlyRole(DEFAULT_ADMIN_ROLE) returns(address){
        require(token0 != token1, "Factory: Same adresses");
        require(token0 != address(0) && token1 != address(0), "Factory: Zero address");
        require(pair[token0][token1] == address(0), "Factory: Pair is exists already"); 
        ERC20Pair _pair = new ERC20Pair(token0, token1, msg.sender);
        address _address = address(_pair); 
        pair[token0][token1] = _address;
        pair[token1][token0] = _address; 
        allPairs.push(_address);

        return _address;
    }  
}
