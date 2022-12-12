//// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "./lib/Position.sol";
import "./lib/Tick.sol";
import "./interfaces/IUniswapV3MintCallback.sol";
import "./interfaces/IERC20.sol";

contract UniswapV3Pool {
    using Tick for mapping(int24 => Tick.Info);
    using Position for mapping(bytes32 => Position.Info);
    using Position for Position.Info;

    error InvalidTickRange();
    error Invalidliquidity(uint256 amount);
    error InsufficientInputAmount();

    int24 internal constant MIN_TICK = -887272;
    int24 internal constant MAX_TICK = -MIN_TICK;

    address immutable token0;
    address immutable token1;

    mapping(int24 => Tick.Info) public ticks;
    mapping(bytes32 => Position.Info) public positions;

    uint128 public liquidity;

    struct Slot0 {
        uint160 sqrtPriceX96;
        int24 tick;
    }

    Slot0 public slot0;

    event Mint(
        address caller,
        address owner,
        int24 lowerTick,
        int24 upperTick,
        uint128 amount,
        uint256 amount0,
        uint256 amount1
    );
    event Swap(
        address caller,
        address recipient,
        int256 amount0,
        int256 amount1,
        uint160 sqrtPriceX96,
        uint128 liquidity,
        int24 tick
    );

    struct CallbackData {
        address token0;
        address token1;
        address payer;
    }

    constructor(address token0_, address token1_, uint160 sqrtPriceX96, int24 tick) {
        token0 = token0_;
        token1 = token1_;

        slot0 = Slot0({sqrtPriceX96: sqrtPriceX96, tick: tick});
    }

    ///@param owner take in the owner, to track the liquidity of the owner and stiore it
    ///@param amount amount of liquidity to take in
    function mint(address owner, int24 lowerTick, int24 upperTick, uint128 amount, bytes memory)
        external
        returns (uint256 amount0, uint256 amount1)
    {
        if (lowerTick >= upperTick || lowerTick < MIN_TICK || upperTick > MAX_TICK) revert InvalidTickRange();
        if (amount == 0) revert Invalidliquidity(amount);
        ticks.update(lowerTick, amount);
        ticks.update(upperTick, amount);

        Position.Info storage position = positions.get(owner, lowerTick, upperTick);
        position.update(amount);
        amount0 = 0.99897661834742528 ether;
        amount1 = 5000 ether;
        liquidity += uint128(amount);
        uint256 balance0Before;
        uint256 balance1Before;
        IUniswapV3MintCallback(msg.sender).uniswapV3MintCallback(amount0, amount1);
        if (amount0 > 0) balance0Before = balance0();
        if (amount1 > 0) balance1Before = balance1();

        if (amount0 > 0 && balance0Before + amount0 > balance0()) {
            revert InsufficientInputAmount();
        }
        if (amount1 > 0 && balance1Before + amount1 > balance1()) {
            revert InsufficientInputAmount();
        }
        emit Mint(msg.sender, owner, lowerTick, upperTick, amount, amount0, amount1);
    }

    function swap(address recipient, bytes memory data) public returns (int256 amount0, int256 amount1) {
        int24 nextTick = 85184;
        uint160 nextPrice = 5604469350942327889444743441197;

        amount0 = -0.008396714242162444 ether;
        amount1 = 42 ether;
        (slot0.sqrtPriceX96, slot0.tick) = (nextPrice, nextTick);
        IERC20(token0).transfer(address(recipient), uint256(-amount0));

        uint256 balance1Before = balance1();
        IUniswapV3SwapCallback(msg.sender).uniswapV3SwapCallback(amount0, amount1);
        if (balance1Before + uint256(amount1) < balance1()) {
            revert InsufficientInputAmount();
        }
        emit Swap(msg.sender, recipient, amount0, amount1, slot0.sqrtPriceX96, liquidity, slot0.tick);
    }

    function balance0() public view returns (uint256 balance) {
        balance = IERC20(token0).balanceOf(address(this));
    }

    function balance1() public view returns (uint256 balance) {
        balance = IERC20(token1).balanceOf(address(this));
    }
}
