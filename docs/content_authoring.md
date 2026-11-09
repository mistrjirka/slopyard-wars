# Editing game content

The three catalogues are ordinary Godot text Resources. Select one in the FileSystem dock, expand its array in the Inspector and edit an entry. Duplicate an entry to add content, give it a unique ID, and keep it in the catalogue array. A text editor works too; preserve the resource references and array entries at the bottom of each file. No content-generation script is required.

| Catalogue | Entry schema | What it controls |
| --- | --- | --- |
| `resources/characters.tres` | `src/data/character_definition.gd` | Identity, voice, negotiation, expertise and schedule |
| `resources/hardware.tres` | `src/data/part_definition.gd` | Model specs, prices, condition range and tuning traits |
| `resources/world_activities.tres` | `src/data/world_activity_definition.gd` | Locations, art, interactions, costs, limits and rewards |

Restart the run after editing content. Shared Resources are definitions; every run creates separate runtime inventory and player state. Renaming a display name should not change its stable ID. Some hardware IDs retain names from the original prototype deliberately.

## Characters

`system_prompt` describes the person's perspective, humor, conversational habits and limits. `favorite_topics`, `pet_peeves` and `technical_knowledge` supplement it in every LLM request. A character can be a seller or an NPC buyer. The provider also receives factual hardware notes, the current conversation and feasible appointment choices.

The current roster includes Sunny Dave, Granite Greta, Slick Vic, Haggle Hank, Desperate Dana, Professor Pixel, Gentle Gus, Stone Sally, Fast Eddie, Bargain Bella, Broke Brandon and Benchmark Bea. Their jokes have different premises: rehabilitating abandoned PCs, receipt archaeology, haunted coil whine, involuntary auctioneering, a tiny moving expedition, sandwich peer review, snail racing, office-PC unions, a slow racing bicycle, coupon strategy, RGB research and benchmarking the kettle.

Behavior fields have actual mechanical effects:

| Field | Meaning |
| --- | --- |
| `price_floor_fraction` | Seller's minimum as a fraction of asking price, with small per-listing variation |
| `counter_bias` | How firmly the contact counters below-floor offers; higher favors the asking price |
| `buyer_budget_range` | NPC buyer's spending range as a multiplier of condition-adjusted reference value |
| `technical_knowledge` | 0 novice, 1 hobbyist, 2 expert; novices admit uncertainty, experts can quote verified specs |
| `meeting_places` | Names from `Catalog.LOCATIONS`; at least one required |
| `hours` | Daily `Vector2i(start_hour, end_hour)` windows; 0–24, end greater than start |
| `schedule_note` | Human-readable description of availability |

Offline play uses the authored `greeting`, `price_accept`, `price_counter`, `technical_reply`, `buyer_opening` and `smalltalk`. Price templates replace `{price}` with the number. Write these as well as the prompt so a character remains recognizable without a provider. The game validates the price and appointment regardless of the character's prose.

## Hardware

Manufacturers and names are fictional. The current conventions are LVD LuckyForce LTX/LGX, LMD Ladeon LDX, LMD LuckyZen and LTL LuckyCore. X5D denotes cache-focused LuckyZen chips; L is the unlocked LuckyCore suffix. Examples include LuckyForce LTX 5090, Ladeon LDX 9070, LuckyZen 7 5800X5D and LuckyCore L7-4790L. Older LGX 750 Li / 1060 cards and older CPUs remain useful budget choices.

`stats` contains compatibility and rated performance: `socket`, `memory`, `form`, `watts`, PSU `capacity`, `integrated`, and category scores `cpu`, `gpu`, `ram`, `storage`. CPU `gpu` is integrated graphics performance; motherboard `integrated` means the board has usable video outputs. Socket names OX3/OX4/NX5/LX7 and all performance numbers are fictional game balance. LuckyCore 12/13/14-series models use LX7; the L670M board takes DDR4 and the L790 takes DDR5.

| Field | Meaning |
| --- | --- |
| `model_id` | Unique stable identifier, also used by salvage pools |
| `manufacturer`, `product_family`, `display_name` | Display branding; independent from identity |
| `base_price` | Reference value before condition; asks are randomized around it |
| `condition_min`, `condition_max` | Per-unit condition range, 1–100; minimum must not exceed maximum |
| `stock_clock_mhz`, `cores`, `capacity_gb` | Buying information; rated category scores drive the benchmark |
| `oc_potential` | Maximum additional clock under ideal conditions: 0.25 means +25% |
| `voltage_limit` | Model's normalized comfort limit; risk begins near it, not only at the hard limit |
| `thermal_load` | Relative heat generation, where lower is easier to cool |
| `stock_failure_chance` | Inherent model failure probability at pristine condition, even at stock; zero by default |
| `fire_base_chance` | Connector-fire chance per test at stock and pristine condition; zero disables this failure mode |
| `fire_power_sensitivity` | Additional fire chance per unit of extra normalized power, adjusted for PSU regulation, heat and condition |
| `support_quality` | Case airflow, motherboard VRM quality or PSU regulation, 0–100 |
| `buying_notes` | Explain the model's practical tradeoffs in plain language |

Condition scales rated performance and value by `0.75 + 0.25 × condition / 100`. Support-part quality is condition-adjusted too. A promising model can be a poor purchase if worn or overpriced. X5D entries deliberately combine high stock scores with modest clock headroom and lower voltage tolerance; the L-suffix LuckyCore offers more tuning room.

`Overclock.evaluate` is the one tuning calculation used by UI, score and host. It combines hardware support, condition, clock and voltage stress, and heat. Lucky's blessing reduces a nonzero failure probability by 25%, then expires on the attempted test. Tests above 1.40× voltage always destroy the component. Safe presets search for a zero-risk setting on normal models; faulty models return stock and the UI explicitly labels it lowest risk, not safe. Successful risky tests cause wear, and previewed scores include that wear. The chance is per test, not a continuous background hazard.

### Model reliability

The real-world reference is [Intel's documented 13th/14th-generation desktop instability issue](https://www.intel.com/content/www/us/en/support/articles/000102331/processors.html). The game uses fictional brands and deliberately exaggerated **game balancing probabilities**, not real failure statistics. Following the selected reference, 12th-generation LuckyCore alternatives do not have the inherent flaw.

| Fictional model | Base stock failure chance per test at condition 100 |
| --- | --- |
| LuckyCore L7-13700L | 12% |
| LuckyCore L9-13900L | 18% |
| LuckyCore L7-14700L | 15% |
| LuckyCore L9-14900L | 22% |
| Added 12th-generation models and 13th/14th-series mainstream L5 models | 0% |

These values are fields on individual Resources; there are no model-name checks in gameplay code. Effective stock risk is `base × (1 + (100 − condition) × 0.008)`, capped at 95%. Tuning risk combines independently as `1 − (1 − stock risk) × (1 − tuning risk)`, then Lucky applies its 0.75 multiplier. Cooling and cleaning cannot erase a model flaw, although cleaning removes the extra risk from wear.

The four affected CPUs are cheaper relative to their stock scores. A listing displays the current stock failure chance before purchase. Every stress test can expose the fault; a valid finished rig also runs one final CPU reliability test. Waiting for the deadline or disconnecting still finalizes that test once. Failure removes the CPU and yields an invalid zero-score build. Passing can still cause wear. Finishing confirmation shows the chance; UI score previews never gamble the part.

### Connector fires

LuckyForce LTX 4090 and 5090 have an authored connector flaw, nicknamed **Dragon Breath mode**. These exaggerated fictional fire mechanics refer to real connector-overheating reports: [NVIDIA's 4090 connector update](https://nvidia.custhelp.com/app/answers/detail/a_id/5413) and [DSOGaming's firsthand 5090 melted-cable report](https://www.dsogaming.com/articles/our-nvidia-geforce-rtx-5090-12v-2x6-power-cable-has-melted/). Neither the probabilities nor the overclock scaling below claim to describe real failure rates or causes.

| Model | Pristine stock fire chance per test | `fire_power_sensitivity` |
| --- | --- | --- |
| LuckyForce LTX 4090 | 1.5% | 0.10 |
| LuckyForce LTX 5090 | 2.5% | 0.14 |

Only models with a positive `fire_base_chance` use this failure mode. Extra power is `max(0, clock × voltage² − 1)`. Poor PSU regulation increases the extra-power contribution; heat above 82 fictional degrees adds more risk. Wear multiplies the combined fire risk by `1 + (100 − condition) × 0.008`, capped at 85%. Better airflow/paste can reduce heat stress, and cleaning can reduce wear, but neither cures the stock connector flaw. The conservative preset therefore returns stock and is labeled **LOWEST RISK: STOCK**.

Fire is included in total destruction: `total = fire + (1 − fire) × other failure risk`. Lucky multiplies both by 0.75 for one eligible test. Above 1.40× voltage, total destruction remains guaranteed without using a blessing. One host roll selects fire, other damage or survival, so there is no hidden second fire roll. The marketplace discloses stock fire risk; tuning readouts and confirmations show the exact fire chance within total destruction. Fire removes only the tested part, clears its tuning and records the cause in the event log and `last_stress_test`; survivors still take wear.

The final benchmark tests inherently risky parts in CPU, GPU, RAM order using a pure plan shared with the finish dialog. A single blessing applies to the first eligible test only. Tests stop if the rig can no longer run. A destroyed GPU can fall back to usable integrated graphics; otherwise it leaves a zero-score build. The deadline and disconnect path use the same once-only finalization, and score previews never perform tests.

## World activities

Each entry supplies an `id`, `area`, reachable `position`, interaction `radius`, description, button label, costs, limits and `result_lines`. `art_key` refers to an explicit texture preload in `Art.WORLD`; `art_size` gives its world dimensions. Optional `overlay_art_key`/`overlay_art_size` layer an existing prop over it, as with Lucky's statue. The five installed placeholder files can be repainted without changing these settings.

| Kind | Current example | Effect |
| --- | --- | --- |
| `lucky` | Lucky's Silicon Shrine | $5 / 5 minutes, one/day, one non-stacking blessing |
| `salvage` | Bin of Dubious Destiny | 25 minutes, one/day; random worn part from `loot_models`, with `loot_condition` bounds |
| `clean` | Warranty Void Laundromat | $12 / 15 minutes; `strength` condition restored, once per owned part per run |
| `cooling` | Thermal Paste Appreciation Society | $18 / 10 minutes; buys and immediately applies LuckyGoop Dragon Chill, +12 rig cooling, once per run |
| `advice` | Benchmark Confessional | Free proverb plus current build advice; 30-minute cooldown |

For existing mechanics, add or edit entries through data. New mechanic types need validation and an effect in `ActivitySystem`; keep that separate from UI and data. Costs are validated before granting rewards. Solo pays time immediately; LAN uses a per-player busy timer. Art does not define collision: keep interaction positions reachable in `world_rules.gd`.

Cooling activities can set `reward_name` (currently **LuckyGoop Dragon Chill**) and `strength` in the resource. The name and bonus appear at the tuning bench. This is an applied treatment, not a loose inventory item: it persists across part swaps until the run ends. Cooling is capped at 100 points; the paste helps temperatures and stable headroom, not the inherent CPU/connector fault. The existing Paste Club placeholder is reused; no additional artwork is required.

## Check changes

Import first, then run `tests/run.ps1 -Godot 'C:/path/to/Godot_console.exe' -IncludeLan`. Content checks validate identities, schedules, hardware notes, branding, safe presets, destruction, price consequences and encounter rules. The suite expects the current catalogue count; update that expectation intentionally when adding/removing models. It never calls the paid dialogue provider.
