// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./interfaces/IFactory.sol";
import "./interfaces/IPair.sol";
import "./interfaces/IWETH.sol";

contract Router is AccessControl, ReentrancyGuard {
    using SafeERC20 for IERC20;

    address public immutable WETH;
    address public immutable factory;

    modifier expire(uint deadline) {
        require(deadline >= block.timestamp, "Router: Expired");
        _;
    }

    constructor (address _factory, address _WETH){
        factory = _factory;
        WETH = _WETH;
    }

    function addLiquidity(
        address _token0, 
        address _token1, 
        uint _amount0, 
        uint _amount1, 
        uint _deadline
    )
        external 
        expire(_deadline) 
        nonReentrant()
    {
        address _user = msg.sender;
        address _pair = IFactory(factory).pair(_token0, _token1);
        require(IERC20(_token0).balanceOf(_user) >= _amount0 && IERC20(_token1).balanceOf(_user) >= _amount1, "Router: Not enough tokens");
        require(_token0 != WETH && _token1 != WETH, "Router: Wrong token adresses");
        if(_pair == address(0)){
            _pair = IFactory(factory).createPair(_token0, _token1);          
        }
        (uint _nAmount0, uint _nAmount1) = IPair(_pair)._lpMint(_user, _amount0, _amount1);
        IERC20(_token0).safeTransferFrom(_user, _pair, _nAmount0);
        IERC20(_token1).safeTransferFrom(_user, _pair, _nAmount1);
    }

    function addLiquidityETH(
        address _token, 
        uint _amount, 
        uint _deadline
    )
        external 
        payable 
        expire(_deadline) 
        nonReentrant()
    {
        address _user = msg.sender;
        uint _value = msg.value;
        require(_value > 100000, "Router: Not enough Ether liquidity");
        address _pair = IFactory(factory).pair(_token, WETH);
        require(IERC20(_token).balanceOf(_user) >= _amount, "Router: Not enough tokens");
        if(_pair == address(0)){
            _pair = IFactory(factory).createPair(_token, WETH);          
        }
        (uint _nAmount0, uint _nAmount1) = IPair(_pair)._lpMint(_user, _amount, _value);
        IERC20(_token).safeTransferFrom(_user, _pair, _nAmount0);
        IWETH(WETH).deposit{value: _nAmount1}();
        (bool success) = IWETH(WETH).transfer(_pair, _nAmount1);
        require(success);
        if(_value > _nAmount1){
            uint _refund = _value - _nAmount1;
            (bool success1,) = _user.call{value: _refund}("");
            require(success1);
        }
    }

    function removeLiquidity(
        address _token0, 
        address _token1, 
        uint _amount, 
        uint _deadline
    )
        external 
        expire(_deadline) 
        nonReentrant()
    {
        address _user = msg.sender;
        address _pair = IFactory(factory).pair(_token0, _token1);
        require(IERC20(_pair).balanceOf(_user) >= _amount, "Router: Not enough LP tokens");
        (uint _amountOut0, uint _amountOut1) = IPair(_pair)._lpBurn(_user, _amount);
        IERC20(_token0).safeTransferFrom(_pair, _user, _amountOut0);
        IERC20(_token1).safeTransferFrom(_pair, _user, _amountOut1);
    }

    function removeLiquidityETH(
        address _token, 
        uint _amount, 
        uint _deadline
    )
        external 
        expire(_deadline) 
        nonReentrant()
    {
        address _user = msg.sender;
        address _pair = IFactory(factory).pair(_token, WETH);
        require(IERC20(_pair).balanceOf(_user) >= _amount, "Router: Not enough LP tokens");
        (uint _amountOut0, uint _amountOut1) = IPair(_pair)._lpBurn(_user, _amount);
        IERC20(_token).safeTransferFrom(_pair, _user, _amountOut0);
        IWETH(WETH).transferFrom(_pair, address(this), _amountOut1);
        IWETH(WETH).withdraw(_amountOut1);
        (bool success,) = _user.call{value: _amountOut1}("");
        require(success);
    }

    function swapExactTokensForTokens(
        address[] calldata path, 
        uint _amountIn, 
        uint _deadline
    )
        external 
        expire(_deadline) 
        nonReentrant()
    {
        swapExactTokensForTokensInternal(path, _amountIn);       
    }
    
    function swapTokensForExactTokens(
        address[] calldata path, 
        uint _desiredAmountOut, 
        uint _deadline
    )
        external 
        expire(_deadline) 
        nonReentrant()
    {
        uint[] memory amounts;
        amounts = utility.getAmountsIn(factory, _desiredAmountOut, path);
        swapExactTokensForTokensInternal(path, amounts[0]);   
    } 

    function swapExactTokensForETH(
        address[] calldata path, 
        uint _amountIn, 
        uint _deadline
    )
        external 
        expire(_deadline)
        nonReentrant()
    {
        swapExactTokensForETHInternal(path, _amountIn);
    }

    function swapTokensForExactETH(
        address[] calldata path,
        uint _desiredAmountOut,
        uint _deadline
    )
        external 
        expire(_deadline) 
        nonReentrant()
    {
        uint[] memory amounts;
        amounts = utility.getAmountsIn(factory, _desiredAmountOut, path);
        swapExactTokensForETHInternal(path, amounts[0]);
    }

    function swapExactETHForTokens(
        address[] calldata path, 
        uint _deadline
    )
        external 
        payable 
        expire(_deadline) 
        nonReentrant()
    {
        require(path[0] == WETH && path[path.length -1] != WETH, "Router: Wrong path");
        address _user = msg.sender;
        uint _amountIn = msg.value;
        require(_amountIn > 0, "Router: Invalid Ether amount");
        address _to;
        IWETH(WETH).deposit{value: _amountIn}();
        if(path.length == 2){
            require(IFactory(factory).pair(path[0], path[1]) != address(0), "Router: Pair is not exist");
            _to = _user;
            IWETH(WETH).transfer(IFactory(factory).pair(path[0], path[1]), _amountIn);
        } else {
            _to = address(this);
        }
        uint _amountOut = _swap(path, _amountIn, _to);
        if(path.length > 2){
            IERC20(path[path.length-1]).safeTransfer(_user, _amountOut);
        }
    }

    function swapETHForExactTokens(
        address[] calldata path, 
        uint _desiredAmountOut, 
        uint _deadline
    )
        external 
        payable 
        expire(_deadline) 
        nonReentrant()
    { 
        require(path[0] == WETH && path[path.length -1] != WETH, "Router: Wrong path");
        uint _value = msg.value;
        uint[] memory amounts;
        amounts = utility.getAmountsIn(factory, _desiredAmountOut, path);
        uint _amountIn = amounts[0];
        require(_value >= _amountIn, "Router: Not enough Ether");
        address _to;
        IWETH(WETH).deposit{value: _amountIn}();
        if(path.length == 2){
            require(IFactory(factory).pair(path[0], path[1]) != address(0), "Router: Pair is not exist");
            _to = msg.sender;
            IWETH(WETH).transfer(IFactory(factory).pair(path[0], path[1]), _amountIn);
        } else {
            _to = address(this);
        }
        uint _amountOut = _swap(path, _amountIn, _to);
        if(path.length > 2){
            IERC20(path[path.length-1]).safeTransfer(msg.sender, _amountOut);
        }
        if(_value > _amountIn){
            uint _refund = _value - _amountIn;
            (bool success,) = msg.sender.call{value: _refund}("");
            require(success);
        }
    }

    receive()external payable{
        require(msg.sender == WETH, "Router: Caller must be WETH");
    }

    function _swap(address[] calldata path, uint _amountIn, address _to)internal returns(uint){
        require(path.length > 1, "Router: Invalid path");
        address _pair;
        for (uint i; i < path.length - 1; i++){
            _pair = IFactory(factory).pair(path[i], path[i+1]);
            require(_pair != address(0), "Router: Invalid path");
            _amountIn =  _amountIn * 997 / 1000;
            if(path.length > 2){
                IERC20(path[i]).safeTransfer(_pair, _amountIn);
            }
            _amountIn = IPair(_pair)._swap(path[i], _amountIn, _to);
            require(_amountIn > 0, "Router: 0x00");
            IPair(_pair)._updateReserves();
        }

        return _amountIn;
    }

    function swapExactTokensForTokensInternal(address[] calldata path, uint _amountIn)internal {
        address _user = msg.sender;
        require(IERC20(path[0]).balanceOf(_user) >= _amountIn, "Router: Not enough tokens to swap");
        require(path[path.length -1] != WETH && path[0] != WETH, "Router: Wrong path");
        address _to;
        if(path.length == 2){
            require(IFactory(factory).pair(path[0], path[1]) != address(0), "Router: Pair is not exist");
            _to = _user;
            IERC20(path[0]).safeTransferFrom(_user, IFactory(factory).pair(path[0], path[1]), _amountIn);
        } else {
            IERC20(path[0]).safeTransferFrom(_user, address(this), _amountIn);
            _to = address(this);
        }
        uint _amountOut = _swap(path, _amountIn, _to);
        if(path.length > 2){
            IERC20(path[path.length-1]).safeTransfer(_user, _amountOut);
        }
    }

    function swapExactTokensForETHInternal(address[] calldata path, uint _amountIn)internal {
        address _user = msg.sender;
        require(IERC20(path[0]).balanceOf(_user) >= _amountIn, "Router: Not enough tokens to swap");
        require(path[path.length - 1] == WETH, "Router: Wrong path");
        if(path.length == 2){
            require(IFactory(factory).pair(path[0], path[1]) != address(0), "Router: Pair is not exist");
            IERC20(path[0]).safeTransferFrom(_user, IFactory(factory).pair(path[0], path[1]), _amountIn);
        } else {
            IERC20(path[0]).safeTransferFrom(_user, address(this), _amountIn);
        }    
        uint _amountOut = _swap(path, _amountIn, address(this));
        IWETH(WETH).withdraw(_amountOut);
        (bool success,) = _user.call{value: _amountOut}("");
        require(success);
    }
}

library utility{
    
    function getReserves(address factory, address tokenA, address tokenB)internal view returns(uint reserveA, uint reserveB){
        (uint reserve0, uint reserve1) = IPair(IFactory(factory).pair(tokenA, tokenB)).getReserves();
        if(IPair(IFactory(factory).pair(tokenA, tokenB)).token0() == tokenA){
            (reserveA, reserveB) = (reserve0, reserve1);
        } else {
            (reserveA, reserveB) = (reserve1, reserve0);
        }     
    }

    function getAmountIn(uint amountOut, uint reserveIn, uint reserveOut)public pure returns(uint amountIn){
        require(amountOut > 0, "Router: Insufficient output amount"); 
        require(reserveIn > 0 && reserveOut > 0, "Router: Insufficient liquidity");
        uint numerator = reserveIn * amountOut * 1003;
        uint denominator = (reserveOut - amountOut) * 1000;
        amountIn = (numerator / denominator);
    }

    function getAmountsIn(address factory, uint amountOut, address[] memory path)internal view returns(uint[] memory amounts){
        require(path.length >= 2, "Router: Invalid path");
        amounts = new uint[](path.length);
        amounts[amounts.length - 1] = amountOut;
        for (uint i = path.length - 1; i > 0; i--) {
            (uint reserveIn, uint reserveOut) = getReserves(factory, path[i - 1], path[i]);
            amounts[i - 1] = getAmountIn(amounts[i], reserveIn, reserveOut);
        }
    }
}
