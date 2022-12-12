//// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "../lib/forge-std/src/Test.sol";
import "../lib/solmate/src/tokens/ERC20.sol";
import "../src/UniswapV3Pool.sol";
import "./TestUtils.sol";

contract UniswapV3PoolTest is Test, TestUtils {
    ERC20Mintable public token0;
    ERC20Mintable public token1;
    UniswapV3Pool public pool;
    address public user = genAddress("user");

    bool transferInMintCallback = true;
    bool transferInSwapCallback = true;

    struct TestCaseParams {
        uint256 wethBalance;
        uint256 usdcBalance;
        int24 currentTick;
        int24 lowerTick;
        int24 upperTick;
        uint128 liquidity;
        uint160 currentSqrtP;
        bool transferInMintCallback;
        bool transferInSwapCallback;
        bool mintLiqudity;
    }

    function setUp() public {
        token0 = new ERC20Mintable("token0", "TKN1", uint8(18));
        token1 = new ERC20Mintable("token1", "TKN2", uint8(18));
    }

    ////////////////////////////////////////////////////////////////////////////
    //
    // CALLBACKS
    //
    ////////////////////////////////////////////////////////////////////////////
    function uniswapV3SwapCallback(int256 amount0, int256 amount1, bytes calldata data) public {
        if (transferInSwapCallback) {
            UniswapV3Pool.CallbackData memory extra = abi.decode(data, (UniswapV3Pool.CallbackData));

            if (amount0 > 0) {
                IERC20(extra.token0).transferFrom(extra.payer, msg.sender, uint256(amount0));
            }

            if (amount1 > 0) {
                IERC20(extra.token1).transferFrom(extra.payer, msg.sender, uint256(amount1));
            }
        }
    }

    function uniswapV3MintCallback(uint256 amount0, uint256 amount1, bytes calldata data) public {
        if (transferInMintCallback) {
            UniswapV3Pool.CallbackData memory extra = abi.decode(data, (UniswapV3Pool.CallbackData));

            IERC20(extra.token0).transferFrom(extra.payer, msg.sender, amount0);
            IERC20(extra.token1).transferFrom(extra.payer, msg.sender, amount1);
        }
    }

    ////////////////////////////////////////////////////////////////////////////
    //
    // INTERNAL
    //
    ////////////////////////////////////////////////////////////////////////////
    function setupTestCase(TestCaseParams memory params)
        internal
        returns (uint256 poolBalance0, uint256 poolBalance1)
    {
        token0.mint(address(this), params.wethBalance);
        token1.mint(address(this), params.usdcBalance);

        pool = new UniswapV3Pool(
            address(token0),
            address(token1),
            params.currentSqrtP,
            params.currentTick
        );

        if (params.mintLiqudity) {
            token0.approve(address(this), params.wethBalance);
            token1.approve(address(this), params.usdcBalance);

            UniswapV3Pool.CallbackData memory extra =
                UniswapV3Pool.CallbackData({token0: address(token0), token1: address(token1), payer: address(this)});

            (poolBalance0, poolBalance1) =
                pool.mint(address(this), params.lowerTick, params.upperTick, params.liquidity, abi.encode(extra));
        }

        transferInMintCallback = params.transferInMintCallback;
        transferInSwapCallback = params.transferInSwapCallback;
    }
}

contract ERC20Mintable is ERC20 {
    constructor(string memory _name, string memory _symbol, uint8 _decimals) ERC20(_name, _symbol, _decimals) {}

    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }
}
