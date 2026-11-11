# Gameplay balance, version 2

The goal is to make a working budget PC attainable, then reward deliberate
upgrades, route planning and negotiation. Optional preparations compete with
parts. Expensive hardware and a large starting budget should offer distinct
possibilities without making every purchase equally attractive.

## Prices and progression

All 75 model prices were reviewed. Representative pristine catalog anchors:

| Choice | Before | Now |
| --- | ---: | ---: |
| Tin Can case / Boxcar ATX / Glasshouse | $12 / $25 / $60 | $30 / $70 / $155 |
| 350 W / 550 W / 1000 W supply | $20 / $45 / $180 | $35 / $75 / $260 |
| Entry OX4 CPU / modern reliable L5-12400 | $60 / $130 | $100 / $210 |
| DDR4 16 GB / DDR5 32 GB 7200 | $55 / $230 | $85 / $350 |
| SATA 120 GB / NVMe 500 GB / NVMe 2 TB | $18 / $55 / $180 | $40 / $160 / $500 |
| Arcadia A580 / LuckyZen LDX 9070 | $120 / $490 | $160 / $720 |

Actual asking prices are 85–120% of the **condition-adjusted used guide**.
The guide now uses `base × (0.25 + 0.75 × condition / 100)`, rather than the
performance curve, which allowed even a nearly wrecked part to retain 75% of
pristine value. Performance still uses the gentler `0.75 + 0.25 × condition / 100`.
This lets a worn component be a useful budget purchase without also being
nearly pristine money when resold.

Opening supply retains compatible OX3 and OX4 budget builds and guarantees a
reliable CPU, matching motherboard and memory path for NX5 and LX7 as well.
The free spare case can be installed or sold. It is not credited as cash until
the player completes a sale handoff. Fuel remains $3 per car entry; walking is
always available, and transport is not intended to drain a run's budget.

Normal buyers' private valuations range from 82–105% of guide; wealthier
contacts use 90–115%. Their opening offer is 80% of their personal valuation,
capped at the ask. Profit comes from finding a bargain and negotiating, rather
than automatically reselling every ordinary purchase above guide. Public
quick-sale and asking guides remain advice, not promised payments. Recurring
markdowns stop at 75% of guide, and referenced listings keep their price.

## Preparations and time

| Stop | Cash | Game minutes | Reason to use it |
| --- | ---: | ---: | --- |
| Dragon Chill | $80 | 20 | +12 cooling for tuned rigs; no stock score boost |
| Dust Clinic | 8% of current guide, minimum $15 | 25 | Up to +12 condition on a valuable worn component, once per part |
| Lucky shrine | $25 | 10 | One 25% relative reduction on a risky test, once per day |
| Salvage | Free | 45 | One worn budget part per day; a modest catch-up option |
| Advice | Free | 0 | A build hint, with the existing 30-minute cooldown |

The cleaning chooser shows the exact fee, before/after condition and guide
values for the selected item. The host recomputes the fee at purchase and
rejects unaffordable work without changing money, condition, time or limits.
Cleaning a cheap spare or an almost pristine flagship can be poor value.

Standard CPU assembly paste remains included. Dragon Chill is a separate
enthusiast preparation and does not repair missing assembly paste or an uneven
mount. It persists across swaps, cannot stack, and cannot cure model defects.

Support hardware now contributes more to achievable OC headroom: support is
40% case airflow, 35% board VRMs and 25% supply regulation; the headroom support
factor is `0.40 + 0.60 × support`. Voltage raises tunable-part power draw by
`clock × voltage²`, making supply capacity relevant when tuning. Normal stock
and conservative presets retain their existing zero intrinsic failure risk.

## Benchmark rewards and records

The total is `1000 × sum(weight × (component_score / reference)^0.75)`.
References are CPU 10,000; GPU 12,000; RAM 6,000; storage 6,000. Objective weights
are unchanged. Every performance upgrade remains beneficial; diminishing
returns make fixing a weak category compete with buying another top-tier part.
Incomplete/incompatible/overloaded builds still score zero. Leftover cash is
not an added benchmark bonus.

Records use `v2|objective|starting_budget|match_days`, so a $600 one-day run has
its own target instead of competing with a $5,000 seven-day run. Legacy scores
remain in the same save file and are not compared against the new economy.
The results panel identifies the record's budget and duration.

## Noticeable, discounted defects

These are intentionally exaggerated **fictional gameplay probabilities** per
stress test or final reliability check, at pristine condition and stock settings:

| Model | Before | Now | Current catalog price |
| --- | ---: | ---: | ---: |
| LuckyForce LTX 4090 connector fire | 1.5% | 10% | $900 |
| LuckyForce LTX 5090 connector fire | 2.5% | 14% | $1,250 |
| LuckyCore L7-13700L | 12% | 20% | $330 |
| LuckyCore L9-13900L | 18% | 28% | $420 |
| LuckyCore L7-14700L | 15% | 24% | $370 |
| LuckyCore L9-14900L | 22% | 34% | $470 |

The defective parts are discounted against reliable alternatives. A pristine
5090 faces about a 26% chance of at least one fire across two unblessed stock
checks; a 13900L faces about 48% CPU failure across two. Survivor wear makes the
actual second check slightly riskier. Wear and tuning still increase risk,
Lucky reduces it once, and ordinary models do not acquire these flaws.
Warnings, stress-test confirmations and the final-benchmark dialog use the
same host calculation. There are no new continuous background failure rolls.
Existing CPU fault events remain destructive failures, rather than a new
simulation of gradual degradation.

## Reproduce the audit

```sh
godot --headless --path . --script res://scripts/balance_report.gd
```

This compares 19,872 complete powered catalog configurations using the actual
compatibility and benchmark code, at base prices, mean authored condition and
stock clocks. It chooses the cheapest fitting case and sufficient PSU; those
have no stock score advantage. It excludes availability, negotiations, travel,
preparations, overclocks, survivor wear and defect rolls. The full output,
including chosen models for every budget/objective, is written to
`artifacts/balance_report.json`. It is a theoretical ceiling, not a forecast
of what a random run will achieve.

| Starting budget | Maximum Balanced stock score | Best without inherent defects |
| --- | ---: | ---: |
| $600 | 385 | 385 |
| $800 | 487 | 476 |
| $1,000 | 591 | 571 |
| $1,500 | 769 | 737 |
| $2,500 | 1,011 | 985 |
| $5,000 | 1,094 | 1,011 |

The full-stock maximum previously cost $2,200, so $2,500 and $5,000 had the same
stock ceiling. It now costs $3,030 before support upgrades or preparation.
At $600, the previous nominal optimum already contained a top 2 TB drive; the
new Balanced optimum distributes spending across RAM, CPU, graphics and a
500 GB drive. A Storage specialist can still prioritize the top drive.

`tests/balance_tests.gd` also checks 32 opening-market seeds, whole shopping/
pickup/assembly/tuning/finish scenarios, repeat markdowns, actual sale handoffs,
service charging and failure atomicity, optional paste, support upgrades,
comparable records and the service chooser at 1152×720 and 1440×900. Offline
dialogue uses the normal host validation; automated travel/minigame completion
does not establish a human player's pacing. Further play feedback should tune
these anchors, especially defect appetite and the value of enthusiast preparation.
