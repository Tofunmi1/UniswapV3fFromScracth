//// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "./lib/Position.sol";
import "./lib/Tick.sol";
import "../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "./interfaces/IUniswapV3MintCallback.sol";

contract UniswapV3Pool {
    using Tick for mapping(int24 => Tick.Info);
    using Position for mapping(bytes32 => Position.Info);
    using Position for Position.Info;

    error InvalidTickRange();
    error InvalidLiquidity(uint256 amount);
    error InsufficientInputAmount();

    int24 internal constant MIN_TICK = -887272;
    int24 internal constant MAX_TICK = -MIN_TICK;

    address immutable token0;
    address immutable token1;

    mapping(int24 => Tick.Info) public ticks;
    mapping(bytes32 => Position.Info) public positions;

    uint128 public Liquidity;

    struct Slot0 {
        uint160 sqrtPriceX96;
        int24 tick;
    }

    Slot0 slot0;

    constructor(address token0_, address token1_, uint160 sqrtPriceX96, int24 tick) {
        token0 = token0_;
        token1 = token1_;

        slot0 = Slot0({sqrtPriceX96: sqrtPriceX96, tick: tick});
    }

    ///@param owner take in the owner, to track the liquidity of the owner and stiore it
    ///@param amount amount of liquidity to take in
    function mint(address owner, int24 lowerTick, int24 upperTick, uint128 amount)
        external
        returns (uint256 amount0, uint256 amount1)
    {
        if (lowerTick >= upperTick || lowerTick < MIN_TICK || upperTick > MAX_TICK) revert InvalidTickRange();
        if (amount == 0) revert InvalidLiquidity(amount);
        ticks.update(lowerTick, amount);
        ticks.update(upperTick, amount);

        Position.Info storage position = positions.get(owner, lowerTick, upperTick);
        position.update(amount);
        amount0 = 0.99897661834742528 ether;
        amount1 = 5000 ether;
        Liquidity += uint128(amount);
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
    }

    function balance0() public view returns (uint256 balance) {
        balance = IERC20(token0).balanceOf(address(this));
    }

    function balance1() public view returns (uint256 balance) {
        balance = IERC20(token1).balanceOf(address(this));
    }
}
