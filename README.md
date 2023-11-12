## Liquidity

- anything with a price or valuable, must have liquidity

## CEX

- centralised exchanges, use an orderbook(a ledger from both a seller and a trader)

## AMM

- LPs provide liquidity, traders swap and trade

## constant function market maker

- x∗y=k
- prices from a pool are determined by token A in terms of token B
- High demand increases the price
- When plotted, the constant product function is a quadratic hyperbola
- whenever a trade or occurs, a new spot price is calcualated

## uniswap v3

- more changes to the AMM algorithm, more configurable market and more support for stablecoins
- liquidity is added on a price range, and each pool is a set of liquidity positions
- ticks
- concentrated liquidity

## Slot0 variables

```
liquidityuint128
sqrtPriceX96uint160
tickint24
token0address
feeGrowthGlobal0X128uint256
protocolFees.token0uint128
token1address
feeGrowthGlobal1X128uint256
protocolFees.token1uint128
```

## Positions

```
lpaddress
tickLowerIndexint24
tickUpperIndexint24
liquidityuint128
feeGrowthInside0LastX128uint256
feeGrowthInside1LastX128uint256
```

## Ticks

- TickMath converts prices to ticks

```
tickIndexint24
liquidityNetint128
liquidityGrossuint128
feeGrowthOutside0X128uint256
feeGrowthOutside1X128uint256
```

## swaps

- new price must be calculated after each swap is executed
- new tick must be calculated too

