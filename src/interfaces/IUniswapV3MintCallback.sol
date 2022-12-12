//// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

interface IUniswapV3MintCallback {
    function uniswapV3MintCallback(uint256 amount0Owed, uint256 amount1Owed) external;
}

interface IUniswapV3SwapCallback {
    function uniswapV3SwapCallback(int256 amount0Delta, int256 amount1Delta) external;
}
