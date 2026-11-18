// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/// Lab 01: Price impact and slippage on a local Uniswap v4 pool.
///
/// What this lab does (all locally, inside Foundry's test EVM; no network, wallet or funds):
///   1. Deploys Uniswap v4 (PoolManager, PositionManager, a swap router) with the helpers
///      from the official Uniswap Foundation v4-template.
///   2. Creates a 0.30%-fee pool with no hook, starting at a 1:1 price, and adds full-range liquidity.
///   3. Swaps increasing amounts of token0 for token1 from the same starting state and logs
///      the execution price, the price impact, and the pool price after each swap.
///   4. Shows how slippage limits protect a trader: a minimum-output limit, a maximum-input
///      limit, and a deadline each make a swap revert instead of executing at a worse price.

import {Test, console2} from "forge-std/Test.sol";

import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "@uniswap/v4-core/src/types/PoolId.sol";
import {Currency} from "@uniswap/v4-core/src/types/Currency.sol";
import {BalanceDelta} from "@uniswap/v4-core/src/types/BalanceDelta.sol";
import {TickMath} from "@uniswap/v4-core/src/libraries/TickMath.sol";
import {StateLibrary} from "@uniswap/v4-core/src/libraries/StateLibrary.sol";
import {FullMath} from "@uniswap/v4-core/src/libraries/FullMath.sol";
import {LiquidityAmounts} from "@uniswap/v4-core/test/utils/LiquidityAmounts.sol";
import {Constants} from "@uniswap/v4-core/test/utils/Constants.sol";
import {IPositionManager} from "@uniswap/v4-periphery/src/interfaces/IPositionManager.sol";

import {EasyPosm} from "v4-template/test/utils/libraries/EasyPosm.sol";
import {BaseTest} from "v4-template/test/utils/BaseTest.sol";

contract PriceImpactSlippageTest is BaseTest {
    using EasyPosm for IPositionManager;
    using PoolIdLibrary for PoolKey;
    using StateLibrary for IPoolManager;

    uint24 constant FEE_PIPS = 3000; // 0.30% LP fee, in hundredths of a basis point
    int24 constant TICK_SPACING = 60;
    uint128 constant LIQUIDITY = 100e18;

    // Errors raised by the swap router used in the v4-template (hookmate V4 router).
    bytes4 constant SLIPPAGE_EXCEEDED = bytes4(keccak256("SlippageExceeded()"));
    bytes4 constant DEADLINE_PASSED = bytes4(keccak256("DeadlinePassed(uint256)"));

    Currency currency0;
    Currency currency1;
    PoolKey poolKey;
    PoolId poolId;

    function setUp() public {
        // Step 1: deploy Permit2, PoolManager, PositionManager and the swap router (v4-template helper).
        deployArtifactsAndLabel();
        (currency0, currency1) = deployCurrencyPair();

        // Step 2: create a pool with no hook (hooks = address(0)) at a 1:1 starting price.
        poolKey = PoolKey(currency0, currency1, FEE_PIPS, TICK_SPACING, IHooks(address(0)));
        poolId = poolKey.toId();
        poolManager.initialize(poolKey, Constants.SQRT_PRICE_1_1);

        // Step 3: add full-range liquidity through the PositionManager.
        int24 tickLower = TickMath.minUsableTick(TICK_SPACING);
        int24 tickUpper = TickMath.maxUsableTick(TICK_SPACING);
        (uint256 amount0, uint256 amount1) = LiquidityAmounts.getAmountsForLiquidity(
            Constants.SQRT_PRICE_1_1,
            TickMath.getSqrtPriceAtTick(tickLower),
            TickMath.getSqrtPriceAtTick(tickUpper),
            LIQUIDITY
        );
        positionManager.mint(
            poolKey,
            tickLower,
            tickUpper,
            LIQUIDITY,
            amount0 + 1,
            amount1 + 1,
            address(this),
            block.timestamp,
            Constants.ZERO_BYTES
        );
    }

    // ---------------------------------------------------------------------
    // Helpers
    // ---------------------------------------------------------------------

    /// Exact-input swap of token0 for token1. Returns the amount of token1 received.
    function _swapExactIn(uint256 amountIn, uint256 amountOutMin, uint256 deadline) internal returns (uint256) {
        BalanceDelta delta = swapRouter.swapExactTokensForTokens({
            amountIn: amountIn,
            amountOutMin: amountOutMin,
            zeroForOne: true,
            poolKey: poolKey,
            hookData: Constants.ZERO_BYTES,
            receiver: address(this),
            deadline: deadline
        });
        return uint256(int256(delta.amount1()));
    }

    /// Pool price (token1 per token0), scaled by 1e18, read from the pool's sqrtPriceX96.
    function _poolPriceE18() internal view returns (uint256) {
        (uint160 sqrtPriceX96,,,) = poolManager.getSlot0(poolId);
        uint256 p = uint256(sqrtPriceX96);
        return FullMath.mulDiv(p * p, 1e18, uint256(1) << 192);
    }

    /// "Quote" a swap by executing it and then rolling the chain state back.
    /// Real applications use the Uniswap v4 Quoter contract instead.
    function _quoteExactIn(uint256 amountIn) internal returns (uint256 amountOut) {
        uint256 snap = vm.snapshotState();
        amountOut = _swapExactIn(amountIn, 0, block.timestamp);
        vm.revertToState(snap);
    }

    // ---------------------------------------------------------------------
    // Part A: price impact grows with trade size
    // ---------------------------------------------------------------------

    function test_PriceImpactGrowsWithTradeSize() public {
        uint256[5] memory sizes = [uint256(0.1e18), 1e18, 5e18, 10e18, 25e18];
        uint256 midPriceE18 = _poolPriceE18();
        assertEq(midPriceE18, 1e18, "pool should start at a 1:1 price");

        console2.log("Pool: 0.30% fee, full-range liquidity L = 100e18, starting price 1.0 token1 per token0");
        console2.log("All values are in wei (1e18 = 1 token); prices are token1 per token0, scaled by 1e18.");

        uint256 previousImpactBps;
        for (uint256 i = 0; i < sizes.length; i++) {
            uint256 snap = vm.snapshotState(); // every trade starts from the same pool state

            uint256 amountIn = sizes[i];
            uint256 amountOut = _swapExactIn(amountIn, 0, block.timestamp);

            // Execution price = what the trader actually got per token0 (includes the 0.30% fee).
            uint256 execPriceE18 = amountOut * 1e18 / amountIn;
            // Price impact excluding the fee: compare output with the fee-adjusted input at the mid price.
            uint256 amountInAfterFee = amountIn * (1e6 - FEE_PIPS) / 1e6;
            uint256 impactBps = 10_000 - (amountOut * 10_000 / amountInAfterFee);
            uint256 priceAfterE18 = _poolPriceE18();

            console2.log("amount in:", amountIn, "amount out:", amountOut);
            console2.log("  execution price:", execPriceE18, "price impact excl. fee (bps):", impactBps);
            console2.log("  pool price after:", priceAfterE18);

            // A full-range v4 position behaves like x*y=k with virtual reserves x = y = L at price 1.
            uint256 expectedOut = uint256(LIQUIDITY) * amountInAfterFee / (uint256(LIQUIDITY) + amountInAfterFee);
            assertApproxEqRel(amountOut, expectedOut, 1e14, "output should match the constant-product formula (0.01%)");

            assertLt(execPriceE18, midPriceE18, "trader always receives less than the mid price");
            assertLt(priceAfterE18, midPriceE18, "selling token0 pushes the token0 price down");
            if (i > 0) assertGt(impactBps, previousImpactBps, "bigger trades have bigger price impact");
            previousImpactBps = impactBps;

            vm.revertToState(snap);
        }
    }

    // ---------------------------------------------------------------------
    // Part B: slippage limits protect the trader
    // ---------------------------------------------------------------------

    /// With no other activity, a swap with a 0.5% minimum-output limit executes.
    function test_SwapWithinSlippageToleranceSucceeds() public {
        uint256 amountIn = 1e18;
        uint256 quoted = _quoteExactIn(amountIn);
        uint256 minOut = quoted * (10_000 - 50) / 10_000; // 0.5% slippage tolerance

        uint256 received = _swapExactIn(amountIn, minOut, block.timestamp + 60);
        console2.log("quoted:", quoted, " min out (0.5%):", minOut);
        console2.log("received:", received);
        assertGe(received, minOut);
    }

    /// Another trader's large swap lands first and moves the price.
    /// The learner's swap, with the same 0.5% minimum-output limit, now reverts.
    function test_SwapRevertsWhenPriceMovesPastMinOut() public {
        uint256 amountIn = 1e18;
        uint256 quoted = _quoteExactIn(amountIn);
        uint256 minOut = quoted * (10_000 - 50) / 10_000;

        // Someone else sells 5 token0 before our transaction executes.
        _swapExactIn(5e18, 0, block.timestamp);
        uint256 nowWouldReceive = _quoteExactIn(amountIn);
        console2.log("quoted before:", quoted, " min out:", minOut);
        console2.log("would receive after the other trade:", nowWouldReceive);
        assertLt(nowWouldReceive, minOut, "the other trade moved the price past our tolerance");

        vm.expectRevert(SLIPPAGE_EXCEEDED);
        _swapExactIn(amountIn, minOut, block.timestamp + 60);
    }

    /// Exact-output swap: ask for 1 token1 but cap the input below what the pool requires.
    function test_ExactOutputRevertsAboveMaxIn() public {
        uint256 amountOut = 1e18;
        // At a 1:1 mid price, 1 token1 costs more than 1 token0 once the fee and price impact are added.
        uint256 amountInMax = 1e18;

        vm.expectRevert(SLIPPAGE_EXCEEDED);
        swapRouter.swapTokensForExactTokens({
            amountOut: amountOut,
            amountInMax: amountInMax,
            zeroForOne: true,
            poolKey: poolKey,
            hookData: Constants.ZERO_BYTES,
            receiver: address(this),
            deadline: block.timestamp + 60
        });

        // With a realistic cap (1.02 token0) the same request executes.
        BalanceDelta delta = swapRouter.swapTokensForExactTokens({
            amountOut: amountOut,
            amountInMax: 1.02e18,
            zeroForOne: true,
            poolKey: poolKey,
            hookData: Constants.ZERO_BYTES,
            receiver: address(this),
            deadline: block.timestamp + 60
        });
        uint256 paid = uint256(-int256(delta.amount0()));
        console2.log("token0 paid for exactly 1 token1:", paid);
        assertGt(paid, amountInMax);
        assertLe(paid, 1.02e18);
    }

    /// A swap submitted with a deadline that has already passed reverts.
    function test_SwapRevertsAfterDeadline() public {
        vm.warp(1_000_000);
        uint256 deadline = block.timestamp - 1;
        vm.expectRevert(abi.encodeWithSelector(DEADLINE_PASSED, deadline));
        _swapExactIn(1e18, 0, deadline);
    }
}
