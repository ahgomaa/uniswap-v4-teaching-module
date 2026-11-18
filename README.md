# Open Uniswap v4 Teaching Module

[![Lab tests](https://github.com/ahgomaa/uniswap-v4-teaching-module/actions/workflows/test.yml/badge.svg)](https://github.com/ahgomaa/uniswap-v4-teaching-module/actions/workflows/test.yml)

A self-contained, openly licensed teaching module on how Uniswap v4 works. It is a drop-in classroom module that any course teaching blockchain can use, including courses where learners do not write code yet. It teaches from the official Uniswap developer documentation and points learners on to the [v4 docs](https://developers.uniswap.org/docs/protocols/v4/overview) and the hook-developer programs when they are ready to build.

**Status:** In development. One sample lab is available now; the rest is planned.

## Available now

| Lab | Topic | Runs on | Status |
| --- | --- | --- | --- |
| [Lab 01: Price impact and slippage](labs/01-price-impact-and-slippage/) | Create a v4 pool, add liquidity, swap increasing amounts, measure price impact, and see minimum-output, maximum-input and deadline limits revert a swap | Local (Foundry), no funds needed | Available, tested in CI |

Quick start:

```bash
git clone --recurse-submodules https://github.com/ahgomaa/uniswap-v4-teaching-module.git
cd uniswap-v4-teaching-module/labs/01-price-impact-and-slippage
forge test -vv
```

All labs build on the official Uniswap Foundation [`v4-template`](https://github.com/uniswapfoundation/v4-template), pinned as a submodule in [`lib/v4-template`](lib/v4-template) at commit `1fbf95547791f0821a170b88c750cb2e04e6818b`. CI runs `forge test` on every push.

## Planned

The items below are planned, not yet complete. Each release will be a tagged GitHub release with passing CI.

### 1. Foundations and first labs (`v0.1`)

A syllabus and learning-objective map; lecture slides on AMMs and liquidity and on Uniswap v4 architecture (singleton `PoolManager`, flash accounting, concentrated liquidity, optional hooks); a reading path through the official docs; 2 runnable local labs (Lab 01 above, plus a lab on pool setup and adding and removing liquidity).

### 2. Core labs: liquidity, fees and the v4 swap path (`v0.2`)

3 more runnable local labs (concentrated-liquidity ranges, LP fees, and the v4 swap path with `unlock` and settlement); instructor notes; a table mapping each lab to the official docs page it implements.

### 3. Hooks, Sepolia testnet, and transaction ordering and slippage context (`v0.3`)

3 more labs: hook permissions and hook addresses, a simple hook built from the `v4-template` path, and an exercise against the official Uniswap v4 deployment on Ethereum Sepolia (chain ID 11155111) with a matching local Anvil path; a short lesson on transaction ordering and slippage context, sourced from the official docs; one assessment per lab, with worked solutions in a separate instructor folder.

### 4. Public `v1.0` release and instructor guide

All 8 labs passing CI; finalized slides and assessments; an instructor guide with notes on adding the module to finance, accounting and cybersecurity courses without changing the v4 core path; a reuse guide (how to run, adapt and report issues); and an `ADOPTERS.md` list where instructors can record their own use.

## Licenses

- Original code (tests, scripts, Foundry exercises): MIT, see [LICENSE](LICENSE).
- Instructional content (READMEs, lab text, slides, assessments): [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/), see [LICENSE-CONTENT](LICENSE-CONTENT).
- The pinned `v4-template` and the Uniswap code it brings in keep their own licenses and attribution.
