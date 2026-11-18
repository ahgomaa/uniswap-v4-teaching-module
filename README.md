# Open Uniswap v4 Teaching Module

A self-contained, open teaching module on how Uniswap v4 works. It is designed so that any course teaching blockchain can incorporate it. The planned materials include reusable labs, computational notebooks, lecture slides, assessments, and an instructor guide covering swaps, liquidity, price impact, slippage, hooks, and MEV basics.

**Status:** In development

## Purpose

The module will teach Uniswap v4 from the official Uniswap developer documentation, not as a generic DEX overview. Instructors should be able to adopt or adapt the materials in their own blockchain courses, including in finance, accounting, and cybersecurity classes. Independent learners should also be able to follow the sequence without mainnet funds.

## Planned milestones

Work is planned in four milestones. The deliverables below are planned, not yet complete.

### 1. Curriculum and slides (weeks 1–4)

Planned deliverables: a syllabus and learning-objective map; a lecture-slide deck covering AMM and liquidity concepts, Uniswap v4 architecture (singleton `PoolManager`, flash accounting, concentrated liquidity, optional hooks), and a reading path that cites official Uniswap developer documentation; a lab outline for the remaining milestones; a tagged `v0.1` release.

### 2. Swaps, liquidity, price impact, and slippage labs (weeks 5–8)

Planned deliverables: labs and notebooks in which learners execute swaps and liquidity changes, observe how trade size and available liquidity affect price impact, set `amountOutMinimum` / `amountInMaximum` and a deadline, and explain the official distinction between price impact and slippage; instructor notes; a lab-to-docs traceability table; a tagged `v0.2` release.

### 3. Hooks, MEV basics, testnet testing, and assessments (weeks 9–12)

Planned deliverables: labs that deploy or inspect a simple hook using official hook permissions and the `v4-template` / Foundry path; at least one exercise on a public testnet listed in the official Uniswap v4 Deployments documentation, plus a local Anvil path; an MEV-basics lesson limited to official pending-transaction and slippage material, clearly sourced; guided and advanced assessments with worked solutions in a separately marked instructor folder; a tagged `v0.3` release.

### 4. Public release and reuse package (weeks 13–16)

Planned deliverables: a complete `v1.0` release of slides, labs, notebooks, assessments, worked solutions, and an instructor implementation guide; notes on adopting the module in finance, accounting, and cybersecurity classes without changing the Uniswap v4 core path; license and attribution files; a short reuse README (how to run, how to adapt, how to report issues).

## Licenses

The following licenses are planned:

- Instructional content: [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/)
- Original code (notebooks, scripts, Foundry exercises, and templates that wrap official Uniswap examples): MIT
- Official Uniswap code used in the labs will keep its existing licenses and attribution.

A copy of the MIT license is in [LICENSE](LICENSE).
