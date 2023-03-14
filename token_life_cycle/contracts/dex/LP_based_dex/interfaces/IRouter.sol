// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

interface IRouter{
    function addLiquidity(address token0, address token1, uint amount0, uint amount1, uint deadline)external;

    function addLiquidityETH(address token, uint amount, uint deadline)external;

    function removeLiquidity(address token0, address token1, uint amount, uint deadline)external;

    function removeLiquidityETH(address token, uint amount, uint deadline)external;

    function swapExactTokensForTokens(address[] calldata path, uint amountIn, uint deadline)external;

    function swapTokensForExactTokens(address[] calldata path, uint desiredAmountOut, uint deadline)external;

    function swapExactTokensForETH(address[] calldata path, uint amountIn, uint deadline)external;

    function swapTokensForExactETH(address[] calldata path, uint desiredAmountOut, uint deadline)external;

    function swapExactETHForTokens(address[] calldata path, uint deadline)external;

    function swapETHForExactTokens(address[] calldata path, uint desiredAmountOut, uint deadline)external;

}
