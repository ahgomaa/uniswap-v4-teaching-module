# Lab 01: Price impact and slippage on a Uniswap v4 pool

**Status:** Available (sample lab)

In this lab you deploy Uniswap v4 locally, create a pool, add liquidity, and run swaps of increasing size. You will see how trade size moves the price (price impact). You will also see how a minimum-output limit, a maximum-input limit, and a deadline stop a swap from executing at a worse price than the trader accepted (slippage protection).

Everything runs locally inside Foundry's test EVM. No testnet, wallet, faucet, or funds are needed.

The lab is built on the official Uniswap Foundation [`v4-template`](https://github.com/uniswapfoundation/v4-template), pinned as a git submodule at commit [`1fbf955`](https://github.com/uniswapfoundation/v4-template/tree/1fbf95547791f0821a170b88c750cb2e04e6818b) (`1fbf95547791f0821a170b88c750cb2e04e6818b`). It uses the template's deployment helpers (`BaseTest`, `Deployers`, `EasyPosm`) and the Uniswap v4 core and periphery code the template brings in.

## Learning objectives

After this lab, you should be able to:

1. Describe the steps to set up a Uniswap v4 pool: deploy the `PoolManager`, initialize a pool from a `PoolKey`, and add liquidity through the `PositionManager`.
2. Explain why a larger trade gets a worse execution price in an automated market maker (AMM).
3. Tell apart the LP fee, price impact, and slippage.
4. Set a minimum-output limit (`amountOutMin`), a maximum-input limit (`amountInMax`), and a deadline, and predict when each one makes a swap revert.

## Prerequisites

- [Git](https://git-scm.com/) and [Foundry](https://book.getfoundry.sh/getting-started/installation) (`forge`). The lab was tested with forge 1.8.6 and Solidity 0.8.30.
- Basic command-line use. You do not need to write Solidity. Reading the test file is optional but helpful.
- Suggested reading from the official Uniswap docs:
  - [Understanding swaps](https://developers.uniswap.org/docs/get-started/concepts/traders/swaps) (price impact, slippage, protection parameters)
  - [Glossary](https://developers.uniswap.org/docs/get-started/concepts/glossary)
  - [v4 vs v3](https://developers.uniswap.org/docs/protocols/v4/concepts/v4-vs-v3) (singleton `PoolManager`, flash accounting)

## Steps

1. Clone the repository with its submodules:

   ```bash
   git clone --recurse-submodules https://github.com/ahgomaa/uniswap-v4-teaching-module.git
   cd uniswap-v4-teaching-module/labs/01-price-impact-and-slippage
   ```

   If you already cloned without submodules, run `git submodule update --init --recursive` from the repository root.

2. Run all tests and show their logs:

   ```bash
   forge test -vv
   ```

3. Run one part at a time:

   ```bash
   forge test --match-test test_PriceImpactGrowsWithTradeSize -vv      # Part A
   forge test --match-test test_SwapRevertsWhenPriceMovesPastMinOut -vv # Part B
   ```

4. Open [`test/PriceImpactSlippage.t.sol`](test/PriceImpactSlippage.t.sol) and match each log line to the code that produced it.

5. Try the changes in the questions below, then run the tests again.

## What the tests do

| Test | What it shows |
| --- | --- |
| `setUp` | Deploys v4 locally, creates a 0.30%-fee pool with no hook at a 1:1 price, and adds full-range liquidity (L = 100e18). |
| `test_PriceImpactGrowsWithTradeSize` | Swaps 0.1, 1, 5, 10, and 25 token0, each from the same starting state. Logs the output, execution price, price impact (excluding the fee), and pool price after the swap. Checks that impact grows with size and that the output matches the constant-product formula within 0.01%. |
| `test_SwapWithinSlippageToleranceSucceeds` | Quotes a 1-token swap, sets a 0.5% minimum-output limit, and the swap executes. |
| `test_SwapRevertsWhenPriceMovesPastMinOut` | Another trader sells 5 token0 first. The same swap with the same 0.5% limit now reverts with `SlippageExceeded()`. |
| `test_ExactOutputRevertsAboveMaxIn` | Asks for exactly 1 token1 with a 1 token0 input cap and reverts with `SlippageExceeded()`. With a 1.02 cap it executes. |
| `test_SwapRevertsAfterDeadline` | A swap with a deadline in the past reverts with `DeadlinePassed`. |

How the numbers are computed:

- **Execution price** = amount out ÷ amount in. It includes the 0.30% fee.
- **Price impact (excluding fee)** = 1 − amount out ÷ (amount in after the fee × starting price), in basis points (1 bp = 0.01%).
- **Pool price after** comes from the pool's `sqrtPriceX96`, squared.

The test "quotes" a swap by running it and rolling the local chain state back (`vm.snapshotState` / `vm.revertToState`). Real applications use the Uniswap v4 Quoter contract instead.

## Expected output

`forge test -vv` should report `5 passed; 0 failed`. Part A logs raw values in wei (1e18 = 1 token). Rounded, they are:

| Amount in (token0) | Amount out (token1) | Execution price | Price impact excl. fee | Pool price after |
| ---: | ---: | ---: | ---: | ---: |
| 0.1 | 0.0996 | 0.9960 | 10 bps (0.10%) | 0.9980 |
| 1 | 0.9872 | 0.9872 | 99 bps (0.99%) | 0.9804 |
| 5 | 4.7483 | 0.9497 | 475 bps (4.75%) | 0.9073 |
| 10 | 9.0661 | 0.9066 | 907 bps (9.07%) | 0.8269 |
| 25 | 19.9520 | 0.7981 | 1,996 bps (19.96%) | 0.6408 |

Part B logs a quote of about 0.9872 token1 for 1 token0 and a minimum output of about 0.9822. After the other trader's 5-token sale, the same swap would return only about 0.8961, so it reverts instead.

## Questions for learners

1. In Part A, each trade is a fraction of the pool's roughly 100-token reserve. Compare that fraction with the price impact for each row. Use the constant-product formula, amount out = L × x ÷ (L + x), to explain the pattern.
2. Why is the pool price after each swap lower than the execution price the trader received?
3. Change `LIQUIDITY` from `100e18` to `1_000e18` and run Part A again. What happens to price impact for the same trade sizes? What does this tell a trader about deep and shallow pools?
4. The 0.30% fee and price impact both lower the amount out. Which one depends on trade size, and which one does not?
5. In Part B, what is the smallest tolerance (in bps) that would have let the swap go through after the other trader's sale? Change the `50` in that test and run it again. When your tolerance is wide enough, the test fails at the "moved the price past our tolerance" check, because the swap would now go through.
6. Price impact comes from your own trade size. Slippage can also come from other transactions that execute before yours. Which test shows each one?
7. Why does a swap need a deadline as well as a minimum output?

## Limits of this lab

- It uses a local deployment and mock tokens, not a public testnet or real assets.
- It uses one pool with no hook and full-range liquidity. Concentrated ranges and hooks are covered in later labs.
- Quotes come from running a swap and rolling the state back, not from the v4 Quoter.

## Licenses

Code in this lab is MIT ([LICENSE](../../LICENSE)). Lab text is [CC BY 4.0](../../LICENSE-CONTENT). The pinned `v4-template` and its dependencies keep their own licenses.
