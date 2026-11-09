# Slopyard Wars

A **Godot 4.7** used-PC-building race inspired by *Scrapyard Wars*. Start at home, message local sellers on your phone, drive to appointments, build a compatible computer and overclock it before tonight's 22:00 deadline.

## Run

Open `project.godot` in Godot 4.7 and press **F5**, or:

```sh
godot --path .
```

A 1440×900 window is recommended; 1280×720 is supported by the existing stretch settings. No Python/Node server is required to play. The existing Godot AI addon files are preserved, but the plugin is disabled by default and its runtime helper is no longer autoloaded.

## Project structure

The game is organized by feature under `src/`: `core`, `network`, `data`, `trading`, `world`, `workshop`, and `ui`. Menu, lobby, game and results have separate scenes. The `Game` autoload coordinates focused gameplay systems; the optional ENet adapter is separate from the solo simulation.

Characters, hardware and world encounters are editable typed Godot Resources. See [`docs/content_authoring.md`](docs/content_authoring.md) for fields, examples and balancing rules. Controls live in Godot's Input Map; [`docs/architecture.md`](docs/architecture.md) describes ownership, extension points and test commands.

### Characters, hardware and town activities

- **12 distinct contacts** in [`resources/characters.tres`](resources/characters.tres): individual LLM system prompts, technical knowledge, negotiation preferences, meeting schedules and authored offline lines. Professor Pixel peer-reviews sandwiches; Slick Vic sells paranormal PC consultancy; Gentle Gus streams snail racing.
- **75 hardware models** in [`resources/hardware.tres`](resources/hardware.tres), spanning older bargains and newer 5060–5090 / 9060–9070 cards. Fictional manufacturers: LVD **LuckyForce LTX/LGX**, LMD **Ladeon LDX** and **LuckyZen**, LTL **LuckyCore**. Cache-focused LuckyZen CPUs use **X5D**; unlocked LuckyCore CPUs use **L**. X5D models favor stock performance over aggressive tuning.
- **Useful buying information:** condition, stock scores, cores/clocks/capacity, power efficiency, a used-price guide, model OC headroom, heat load and voltage comfort. Case airflow, motherboard VRMs and PSU regulation support the final overclock.
- **Risk and wear:** previews show destruction probability and the score after a surviving test, including wear. Normal models have zero-risk stock/safe presets. Selected LuckyCore 13/14-series L7/L9 CPUs have an explicit reliability flaw even at stock; the final benchmark tests those too. LuckyForce LTX 4090/5090 cards can catch fire at the power connector, especially with extra clock/voltage; the fire probability is included in the displayed destruction risk. The final benchmark checks these too. Their preset is labeled **LOWEST RISK: STOCK**, never safe. Risky tests can permanently destroy the tested part; survivors lose condition, affecting performance and resale value.
- **Five interactive stops** in [`resources/world_activities.tres`](resources/world_activities.tres): Lucky's Silicon Shrine, the Bin of Dubious Destiny, Warranty Void Laundromat, Thermal Paste Appreciation Society and Benchmark Confessional. Find their map markers, walk up and press **E**. Costs and repeat limits appear before using them. Paste Club sells and applies **LuckyGoop Dragon Chill**: +12 rig cooling for the run, including after swaps.

At **Lucky Square**, a $5 offering and five game minutes grant one blessing: the next risky test has **25% less failure chance** (20% becomes 15%). Safe tests preserve it; it cannot stack, is available once per game day, and cannot prevent guaranteed destruction above 1.40× voltage. The prayer: “May my frames be high, my timings tight, and the magic smoke remain inside.”

Five labeled placeholder PNGs are already wired into the world under [`assets/world_activities/`](assets/world_activities/). An artist can overwrite them without code changes; see the [art brief](docs/art_brief.md).

### Changes in this refactor

- Solo setup is the default focus; LAN controls expand from an optional section.
- Supplied building, floor, road, vegetation, car, furniture, statue and computer-part artwork replaces the placeholder drawings. The original character atlas remains.
- Installing a case changes the home workspace from the wooden to the metal furniture variants. Lucky statues decorate the home and town square.
- Waiting advances workbench jobs and market refreshes along with the clock.
- Replay creates a fresh match identity and frees the previous screen. High-score loading tolerates malformed entries.
- Unused automatic-travel/market widgets were removed. The physical negotiation → meeting → handoff → build loop remains.

### Live marketplace characters

Set `OPENROUTER_API_KEY` in the environment, or put a local key in `.local/openrouter.cfg` under `[openrouter]` as `api_key="YOUR_KEY"`. The environment takes priority. The `.local/` directory is ignored by Git and Godot's importer/exporter; keep it private when sharing the project folder. Restart the running game after editing the key. Only the solo process / LAN host makes OpenRouter requests, using **`deepseek/deepseek-v4.1-flash-1017`** with reasoning disabled and a 400-token output ceiling. Provider usage charges apply. Do not embed credentials in source files or exported builds.

Without a key, or on a provider failure, clearly marked **offline** replies keep the trading loop playable. The fallback understands fewer natural-language variations. The game, not the model, owns money, inventory, schedules and transaction validation.

Characters take roughly **2–12 seconds** to reply, with individual pacing. At guide price, a sale's first interested buyer typically arrives after **8–18 game minutes** (about 11–24 real seconds); expensive asks take longer and can get no replies. The Sell screen shows waiting for interest until somebody actually contacts you. Incoming chat bubbles sit on the left, yours on the right, and system notices are centered.

Ask the contacts about their lives: each has a biography, relationships, ambitions and conversation hooks. Gus, Professor Pixel and Brandon prefer a brief personal exchange before bargaining. Every character has interests they take personally: bluntly dismissing those hobbies, directly insulting them or making one extreme lowball can get you blocked immediately. Minor annoyances exhaust their remaining patience quickly too. Blocks cancel your existing deals and stop trading across all that character's listings for the run. Genuine questions, polite redirection and reasonable bargaining remain welcome. Other LAN players keep their own relationships. The prompt and a host text check prevent explicit private-limit explanations such as "above the set minimum" from appearing as valid negotiation dialogue.

## Controls

| Control | Action |
|---|---|
| **WASD / arrow keys** | Walk; drive while in your car |
| **E** | Use doors, car, nearby scheduled handoffs, the home workbench and town activities |
| **P / Tab** | Open or pocket your phone |
| **M** | Town overview and appointment tracking |
| **B / T** | Assembly / overclocking, only beside the workbench inside your house |
| **Space** | Intentionally wait in solo: 30 game minutes, or up to two hours toward a nearby upcoming meeting |
| **Esc** | Close phone, map, workbench or current dialog |

Movement stops while an interface is open. The world clock does **not** pause while you chat. Waiting cannot skip time for other LAN players.

Assembly uses clicks, dragging, cable matching, and **R/E/right-click** rotation where instructed. Overclock dials accept dragging, scrolling and focused arrow-key adjustments.

### LuckyFold Duo

**P / Tab** always brings the phone out of your pocket folded, even if you put it away unfolded. The cover screen shows your inbox or selected conversation and lets you read, type, send quick replies, arrange meetings and track appointments. **UNFOLD** opens the wider marketplace with Browse, Messages and Sell. **FOLD** returns to quick messages. Conversations and unsent drafts survive pocketing and folding, and the last marketplace tab is remembered when you unfold again.

**Browse** combines search with an All / CPU / GPU / RAM / motherboard / PSU / case / storage filter. Sort by price ascending, price descending or newest; cheapest-first is the default. Filters survive folding and tab changes, and live stock updates preserve search focus. **Sell** shows condition-adjusted value, a suggested asking range and a quick-deal guide. Buttons fill the price; advice updates as you edit. Buyers still haggle and require a physical handoff. Price guides do not reveal their private budgets.

The cover has **LuckyFold Duo** printed in the free space beneath its display. The unfolded screen has a fixed bright display-fault band in the lower-right, extending from the hinge to the edge with a thin line continuing downward. The fault ignores input and overlaps the bottom of marketplace browsing. In conversations, the message box's upper edge sits behind the band, with input and Send text below it and to the right of the vertical stripe. Quick replies stay above the band, and the footer remains clear. Hardware notes and the chat appear side by side when unfolded. The device adapts to the available viewport height.

Only **two** new art files are used for both states: a shared nine-patch casing and a transparent fault overlay. See [`assets/ui/luckyfold/README.md`](assets/ui/luckyfold/README.md) for replacement instructions.

## The loop

1. **Start solo or host/join LAN.** Choose a budget and CPU, GPU, Storage or Balanced benchmark objective. You spawn in a furnished house with your PC workbench. A visible old spare case lets you try selling immediately; it isn't cash until actually sold.
2. **Use your phone.** Unfold the LuckyFold Duo: **Browse** shows social-classifieds listing tiles, **Messages** holds individual conversations, and **Sell** lets you list owned spare parts. Hardware notes help you match sockets, memory and power; sellers aren't all experts. Fold it closed for quick messages.
3. **Negotiate price, place and time.** There's no checkout or Buy button. Ordinary-person sellers and buyers can counter, refuse, get impatient or be unsure about technical questions. Each contact has different daytime/evening availability and two possible meeting locations. Ask naturally or use the meeting-suggestion messages.
4. **Check the confirmed meeting.** Agreeing only a price isn't enough. A confirmed appointment shows its **day, time, place and window end**. Track it from the conversation or map. A proposal is not confirmation. An agreement also isn't an exclusive reservation: shared stock still goes to the first valid handoff.
5. **Go there yourself.** Walk through the home door, approach your car and press E. Starting the car costs $3 fuel. Drive around town, park, and walk to the contact. They appear during the agreed window; E transfers the part and payment only at the right place and time. Early? Wait. Missed them? Message to reschedule.
6. **Sell spares.** Post an inventory part and a buyer will open with an offer. Negotiate in Messages, agree a meeting and physically hand it over to receive money. A live listing locks the part from installation; cancelling unlocks it. Installed/destroyed parts can't be listed, and handoffs can't pay twice.
7. **Build at home.** Return to your workbench and assemble case → compatible motherboard → CPU/RAM/graphics/PSU/storage through their minigames. Graphics can come from a discrete card or a CPU with integrated graphics plus a board with video outputs. Wrong purchase? Sell it or swap in compatible hardware.
8. **Tune and benchmark.** CPU/GPU/RAM clock and voltage settings can improve performance, destabilize it, overload the PSU or permanently destroy a part. Finish beside the home workbench. Incomplete rigs score zero with reasons; solo best scores persist locally.

## Clock and appointments

The run lasts **one day, 08:00–22:00**. At **0.75 game minutes per real second**, the full clock lasts **18 minutes 40 seconds**, before solo waits, activity time costs or finishing early. The slower clock leaves more reading and negotiation time within each appointment. Market refreshes happen every game hour. Aim to hunt and collect through the day, then bring the parts home around **19:00** for assembly and tuning. Reminders appear with three game hours and one game hour left; you can keep shopping or finish early. The HUD shows the deadline and approximate real time remaining.

Contacts offer a small set of upcoming feasible windows, generally up to 90 game minutes long, all bounded by tonight's deadline. Different characters prefer different hours and meeting places. New listings and buyers use contacts who still have a feasible window; when none remain, posting a sale is refused without taking the part. Overlapping appointments cannot place the same person at different locations. NPCs currently appear at meetings rather than simulating a full commute/work/home life.

## Multiplayer

- Up to **4 players**, ENet **UDP 24680**. Join the host's LAN address before the match starts. Use `127.0.0.1` for two instances on one machine.
- The host owns movement/collision, time, availability, cash, parts and handoffs; clients send directional/action intents, not teleport coordinates.
- Players have their own car and rig; nearby peers and active contacts are visible. The small home layout is shared rather than separate customizable houses.
- Public matchmaking, NAT traversal, reconnect and unfinished-match saves aren't implemented. Separate-machine LAN connectivity has not been verified.

## Prototype notes

The world uses the supplied pixel-art pack, with the original atlas retained for characters. See [`assets/town/README.md`](assets/town/README.md) for asset wiring. Car controls are simple top-down directional driving, not a vehicle physics simulator. Hardware and benchmarks are fictional. Voltage is a **normalized game multiplier**, not real-world advice: **above 1.40× permanently destroys the component**.

There is no AI rival PC builder in solo; it remains a high-score challenge. LLM dialogue can sometimes be imperfect: use the game's explicit price/meeting status, not a vague chat promise, to check whether a transaction is actually agreed.

See [`docs/backend.md`](docs/backend.md) for state ownership and trading rules.

## Validation

Validation uses Godot 4.7.2: editor import/parsing, the offline regression suite, and a two-process localhost ENet smoke test. Tests exercise gameplay outcomes, authored content and screen lifecycle, disable paid dialogue calls, and use isolated score files. The runner prints the current check count.

```sh
godot --headless --path . --editor --import --quit
godot --headless --path . --script res://tests/run_tests.gd
```

Windows, including LAN and log validation:

```powershell
./tests/run.ps1 -Godot 'C:/path/to/Godot_console.exe' -IncludeLan
```

Interactive visual playtesting was skipped at the user's request. Live-provider dialogue and separate-machine LAN were not re-tested during this refactor. Earlier prototype playthroughs do not constitute visual verification of the new artwork.
