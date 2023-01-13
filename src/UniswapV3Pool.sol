//// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "./lib/Position.sol";
import "./lib/Tick.sol";
import "./lib/TickBitmap.sol";
import "./interfaces/IUniswapV3MintCallback.sol";
import "./interfaces/IERC20.sol";
import "./lib/Math.sol";
import "./lib/TickMath.sol";
import "./lib/SwapMath.sol";
import "./lib/LiquidityMath.sol";

contract UniswapV3Pool {
    using Tick for mapping(int24 => Tick.Info);
    using Position for mapping(bytes32 => Position.Info);
    using Position for Position.Info;

    error InvalidTickRange();
    error Invalidliquidity(uint256 amount);
    error InsufficientInputAmount();
    error ZeroLiquidity();

    int24 internal constant MIN_TICK = -887272;
    int24 internal constant MAX_TICK = -MIN_TICK;

    address immutable token0;
    address immutable token1;

    mapping(int24 => Tick.Info) public ticks;
    mapping(bytes32 => Position.Info) public positions;

    using TickBitmap for mapping(int16 => uint256);

    mapping(int16 => uint256) public tickBitmap;

    uint128 public liquidity;

    //tick and sqrtPriceX96
    struct Slot0 {
        // current price SQRT(P)
        uint160 sqrtPriceX96;
        // current Tick
        int24 tick;
    }

    // struct for filling order
    struct SwapState {
        uint256 amountSpecifiedRemaining;
        uint256 amountCalculated;
        uint160 sqrtPriceX96; //new current price after a swap is done
        int24 tick; // new tick after a swap
    }

    ///@dev
    /// @notice StepState maintains current swap step’s state. This structure tracks the state of one iteration of an “order filling
    ///@notice nextTick is the next initialized tick that will provide liquidity for the swap and sqrtPriceNextX96 is the price at the next tick. amountIn and amountOut are amounts that can be provided by the liquidity of the current iteration.

    struct StepState {
        uint160 sqrtPriceStartX96;
        int24 nextTick;
        uint160 sqrtPriceNextX96;
        uint256 amountIn;
        uint256 amountOut;
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

    ///@param owner take in the owner, to track the liquidity of the owner and store it
    ///@param amount amount of liquidity to take in

    function mint(address owner, int24 lowerTick, int24 upperTick, uint128 amount, bytes calldata data)
        external
        returns (uint256 amount0, uint256 amount1)
    {
        if (lowerTick >= upperTick || lowerTick < MIN_TICK || upperTick > MAX_TICK) revert InvalidTickRange();

        if (amount == 0) revert ZeroLiquidity();

        bool flippedLower = ticks.update(lowerTick, amount);
        bool flippedUpper = ticks.update(upperTick, amount);

        if (flippedLower) {
            tickBitmap.flipTick(lowerTick, 1);
        }

        if (flippedUpper) {
            tickBitmap.flipTick(upperTick, 1);
        }

        Position.Info storage position = positions.get(owner, lowerTick, upperTick);
        position.update(amount);

        Slot0 memory slot0_ = slot0;

        // add liquidity at different ranges
        if (slot0_.tick < lowerTick) {
            amount0 = Math.calcAmount0Delta(
                TickMath.getSqrtRatioAtTick(lowerTick), TickMath.getSqrtRatioAtTick(upperTick), amount
            );
        } else if (slot0_.tick < upperTick) {
            amount0 = Math.calcAmount0Delta(
                TickMath.getSqrtRatioAtTick(slot0_.tick), TickMath.getSqrtRatioAtTick(upperTick), amount
            );
            amount1 = Math.calcAmount1Delta(
                TickMath.getSqrtRatioAtTick(slot0_.tick), TickMath.getSqrtRatioAtTick(lowerTick), amount
            );
            liquidity = LiquidityMath.addLiquidity(liquidity, int128(amount)); // TODO: amount is negative when removing liquidity
        } else {
            amount1 = Math.calcAmount1Delta(
                TickMath.getSqrtRatioAtTick(lowerTick), TickMath.getSqrtRatioAtTick(upperTick), amount
            );
        }

        uint256 balance0Before;
        uint256 balance1Before;
        if (amount0 > 0) balance0Before = balance0();
        if (amount1 > 0) balance1Before = balance1();
        IUniswapV3MintCallback(msg.sender).uniswapV3MintCallback(amount0, amount1, data);
        if (amount0 > 0 && balance0Before + amount0 > balance0()) {
            revert InsufficientInputAmount();
        }
        if (amount1 > 0 && balance1Before + amount1 > balance1()) {
            revert InsufficientInputAmount();
        }

        emit Mint(msg.sender, owner, lowerTick, upperTick, amount, amount0, amount1);
    }

    function swap(address recipient, bool zeroForOne, uint256 amountSpecified, bytes calldata data)
        public
        returns (int256 amount0, int256 amount1)
    {
        //TODO: calculate the next tick mathematically, instead of hardcoding it
        //Bitmap for representing the highs and lows
        // Hardcoding
        // int24 nextTick = 85184;

        Slot0 memory _slot0 = slot0;

        SwapState memory state = SwapState({
            amountSpecifiedRemaining: amountSpecified,
            amountCalculated: 0,
            sqrtPriceX96: _slot0.sqrtPriceX96,
            tick: _slot0.tick
        });

        /// loop through till amount specified becomes zero
        while (state.amountSpecifiedRemaining > 0) {
            StepState memory step;

            step.sqrtPriceStartX96 = state.sqrtPriceX96;

            (step.nextTick,) = tickBitmap.nextInitializedTickWithinOneWord(state.tick, 1, zeroForOne);

            step.sqrtPriceNextX96 = TickMath.getSqrtRatioAtTick(step.nextTick);
            (state.sqrtPriceX96, step.amountIn, step.amountOut) = (
                SwapMath.computeSwapStep(
                    state.sqrtPriceX96, step.sqrtPriceNextX96, liquidity, state.amountSpecifiedRemaining
                )
            );

            state.amountSpecifiedRemaining -= step.amountIn;
            state.amountCalculated += step.amountOut;
            state.tick = TickMath.getTickAtSqrtRatio(state.sqrtPriceX96);
        }

        // if the tick is calculated is correct, update the state

        // Mathematcally calculate the next price too
        // uint160 nextPrice = 5604469350942327889444743441197;

        //TODO: calculate the amount0 and amount1 instead of hardcoding them
        //DONE
        // amount0 = -0.008396714242162444 ether;
        // amount1 = 42 ether;

        // (slot0.sqrtPriceX96, slot0.tick) = (nextPrice, nextTick);
        // IERC20(token0).transfer(address(recipient), uint256(-amount0));
        if (state.tick != _slot0.tick) {
            (slot0.sqrtPriceX96, slot0.tick) = (state.sqrtPriceX96, state.tick);
        }
        // uint256 balance1Before = balance1();
        // IUniswapV3SwapCallback(address(msg.sender)).uniswapV3SwapCallback(amount0, amount1);
        // if (balance1Before + uint256(amount1) < balance1()) {
        // revert InsufficientInputAmount();
        // }

        // we have been hardcoding up to this point, now everything is all calculated
        // swap based on the direction of the boolean provided
        (amount0, amount1) = zeroForOne
            ? (int256(amountSpecified - state.amountSpecifiedRemaining), -int256(state.amountCalculated))
            : (-int256(state.amountCalculated), int256(amountSpecified - state.amountSpecifiedRemaining));

        if (zeroForOne) {
            IERC20(token1).transfer(recipient, uint256(-amount1));

            uint256 balance0Before = balance0();
            IUniswapV3SwapCallback(msg.sender).uniswapV3SwapCallback(amount0, amount1, data);
            if (balance0Before + uint256(amount0) > balance0()) {
                revert InsufficientInputAmount();
            }
        } else {
            IERC20(token0).transfer(recipient, uint256(-amount0));

            uint256 balance1Before = balance1();
            IUniswapV3SwapCallback(msg.sender).uniswapV3SwapCallback(amount0, amount1, data);
            if (balance1Before + uint256(amount1) > balance1()) {
                revert InsufficientInputAmount();
            }
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
