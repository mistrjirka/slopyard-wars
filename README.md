# Slopyard Wars

A **Godot 4.7** solo used-PC-building high-score game inspired by *Scrapyard Wars*. Start at home, message local sellers, drive to appointments, build a compatible computer and overclock it before the final day's 22:00 deadline. Runs default to **two game days**, configurable from one to seven.

## Run

Open `project.godot` in Godot 4.7 and press **F5**, or:

```sh
godot --path .
```

A 1440×900 window is recommended; 1280×720 is supported by the existing stretch settings. No Python/Node server is required to play. The existing Godot AI addon files are preserved, but the plugin is disabled by default and its runtime helper is no longer autoloaded.

For installation practice, choose **ASSEMBLY TEST** on the menu. It opens the workbench with all 75 catalog parts and a compatible installed rig; use **Reinstall** to practise any installed part, or **Uninstall** to try alternatives. The deadline is paused and practice scores are not saved. Sales and timed pickups belong to normal runs; waiting in practice only completes pending workbench jobs.

## Project structure

The game is organized by feature under `src/`: `core`, `network`, `data`, `trading`, `world`, `workshop`, and `ui`. Menu, lobby, game and results have separate scenes. Fixed UI layouts and reusable rows/cards are authored in `.tscn` files beside their feature scripts; scripts bind state, connect signals and populate dynamic content. The shared editor-visible theme is `resources/ui/game_theme.tres`. The `Game` autoload coordinates focused gameplay systems; the optional ENet adapter is separate from the solo simulation.

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

- Solo high-score play is the supported mode; multiplayer menu and connection entry points are disabled.
- Supplied building, floor, road, vegetation, car, furniture, statue and computer-part artwork replaces the placeholder drawings. Players use directional animated sprites; NPCs retain the original character atlas.
- Installing a case changes the home workspace from the wooden to the metal furniture variants. Lucky statues decorate the home and town square.
- Waiting advances stress-test jobs and market refreshes along with the clock. Installation minigames themselves do the work; completion adds no extra installation wait.
- Replay creates a fresh match identity and frees the previous screen. High-score loading tolerates malformed entries.
- Unused automatic-travel/market widgets were removed. The physical negotiation → meeting → handoff → build loop remains.

### Live marketplace characters

Paste your key into **OpenRouter API Key** on the main menu. The password-style field hides the key, blocks copying/cutting and allows pasting with Ctrl+V. It starts with the first configured value from: environment `OPENROUTER_API_KEY`, environment `OPENROUTER_KEY`, project-root `.env` (`OPENROUTER_KEY=...` or `OPENROUTER_API_KEY=...`), then `.local/openrouter.cfg` (`[openrouter]` / `api_key="YOUR_KEY"`). Quoted `.env` values are supported. Menu edits apply immediately and last for the current game process only; they do not overwrite the file. Clear the field to use offline sellers. The key stays local and is never included in match snapshots. Both `.env` and `.local/` are Git-ignored; Godot excludes dotfiles and dotfolders from exported projects. Keep them private when sharing the project folder directly. Restart the running game after editing a credential file. Only the local solo process makes OpenRouter requests, using **`deepseek/deepseek-v4.1-flash-1017`** with reasoning disabled and a 400-token output ceiling. Provider usage charges apply. Do not embed credentials in source files or exported builds.

Without a key, or on a provider failure, clearly marked **offline** replies keep the trading loop playable. The fallback understands fewer natural-language variations. The game, not the model, owns money, inventory, schedules and transaction validation.

Characters have individual reply pacing. Live AI requests have a **40-second total turn budget**, including at most one correction of an inconsistent financial decision; provider latency can exceed the authored pacing. At guide price, a sale's first interested buyer typically arrives after **8–18 game minutes** (about 11–24 real seconds); expensive asks take longer and can get no replies. The Sell screen shows waiting for interest until somebody actually contacts you. Incoming chat bubbles sit on the left, yours on the right, and system notices are centered.

Ask the contacts about their lives: each has a biography, relationships, ambitions and conversation hooks. Gus, Professor Pixel and Brandon prefer a brief personal exchange before bargaining. Every character has interests they take personally: bluntly dismissing those hobbies, directly insulting them or making one extreme lowball can get you blocked immediately. Minor annoyances exhaust their remaining patience quickly too. Blocks cancel your existing deals and stop trading across all that character's listings for the run. Genuine questions, polite redirection and reasonable bargaining remain welcome. The prompt and a host text check prevent explicit private-limit explanations such as "above the set minimum" from appearing as valid negotiation dialogue.

## Controls

| Control | Action |
|---|---|
| **WASD / arrow keys** | Walk; drive while in your car |
| **E** | Use doors, car, nearby scheduled handoffs, the home workbench and town activities |
| **P** | Open or pocket your phone |
| **Tab / Shift+Tab** | Open the phone / move focus forward or backward while it is open |
| **M** | Town overview and appointment tracking |
| **B / T** | Assembly / overclocking, only beside the workbench inside your house |
| **Space** | Intentionally wait in solo: 30 game minutes, or up to two hours toward a nearby upcoming meeting |
| **Esc** | Close phone, map, workbench or current dialog |
| **F8** | Mute / unmute all audio |

Movement stops while an interface is open. The world clock does **not** pause while you chat. Assembly test mode is the exception: its deadline stays paused.

**Sound** in the main menu, or **♪** in the game toolbar, opens independent Master, Music and Effects sliders and a mute switch. Settings are saved locally in `user://audio.cfg`; Escape closes the sound panel. The original 48-second, 80 BPM **Slopyard Afterhours** music loop continues smoothly between screens. Sounds accompany buttons, messages, footsteps, doors, driving, trades, activities, assembly tools, stress-test results and the final score. The first LuckyFold crack plays on the same frame as its screen-failure flash; normal folds and unfolds use edited recordings of a real hinge, cancelled when their animation is interrupted. There are 22 original synthesized playback assets and two edited CC0 hinge recordings by chonkdonk. Source, per-asset license records and the full CC0 text are in [`assets/audio/licenses/`](assets/audio/licenses/). `node scripts/generate_audio.cjs` regenerates the original audio and preserves the recordings; `godot --headless --path . --script res://scripts/prepare_hinges.gd` rebuilds the recorded hinge excerpts.

World encounters, completed handoffs and clock reminders arrive as texts from **Lucky**, a contact that appears by magic in your phone's **Messages**. His conversation is read-only, with a large Lucky portrait on the left of the unfolded display and message history filling the right half down to the bottom. The cover shows the texts alone. New texts preserve your place while reading older ones. Blue dots in the inbox mark unread messages from Lucky, sellers and buyers; opening a conversation clears its dot. Unread counts on **PHONE [P]** and the **Messages** tab announce incoming texts without opening the phone. History lasts for the current match. Invalid actions and immediate feedback, such as pressing E with nothing nearby, stay in the bottom bar.

Messages are split into **Active**, **Agreed** (price, place and time confirmed), and **Finished** conversations. Marketplace cards mark listings you have already messaged, and CPU cards show their socket. When arranging pickup, choose an offered time in the quick-response area; typing pauses during selection. Slot colours and overlap counts describe your other appointments without preventing a choice.

Physical town objects collide at their visible bases rather than their roofs or canopies. Tall objects are depth-sorted with characters and fade as a whole when hiding them. Cars are solid, and the bottom-centre asphalt parking court is driveable. The compact component checklist stays visible beside the open phone. Meeting indicators replace the minimap: grey before start, green during the window, and red **!** during its final ten minutes. Off-screen locations use edge arrows; **M** still opens the full map.

Assembly uses clicks, dragging and **R/right-click** rotation where instructed. Hold left mouse to tighten screws and right mouse to loosen them. Overclock dials accept dragging, scrolling and focused arrow-key adjustments.

Install a case before a motherboard; CPU, RAM, graphics and storage need their compatible board first. The PSU needs only the case. Match the motherboard's standoff holes, lower graphics cards gently, and seat susceptible screws at 100–150% tightness. An unwanted standoff beneath solid PCB causes a damage strike and stops tightening when a screw would pass 50%; back the screw out, lift the board and remove the support. Extra standoffs outside the PCB are harmless. Fast GPU impacts and overtightening can also cause permanent damage: five strikes destroy the part, and retrying or cancelling does not erase damage. Metal case/PSU/GPU-bracket screws do not cause overtightening damage in this game.

Clicking exposed LGA socket pins during CPU placement damages the motherboard, not the CPU. The workbench shows screw coverage and your assembly mistakes for the run; these quality counts add no extra performance penalty.

CPUs include a cooler as a minigame prop, not a separate marketplace item. Too little thermal paste reduces CPU performance by up to 50%; excess paste has no penalty. Tighten opposite cooler corners gradually to preserve cooling and overclocking headroom. Current damage and installation penalties are shown on the bench; **Reinstall** lets you correct paste or mounting, but not physical damage. **Uninstall** returns the part to inventory without a timer; alternatives for that occupied category remain hidden until it is removed. Completed mandatory steps advance automatically, while paste and optional motherboard fastening stay under your control. HDD/SATA drives use a side-view bay with two screws on each side; M.2 NVMe modules use a motherboard connector and one end screw. The GPU bracket has one top screw.

### LuckyFold Duo

The first time you take out the phone each match, its cover introduces the new top-of-the-class folding phone: twice the screen, twice the price, and twice the opportunity for quality control to take a day off. The full-width **Unfold** button opens the marketplace through the existing first-unfold cracking animation. The introduction then stays dismissed for the rest of that match, including after folding or pocketing the phone.

**P / Tab** takes out the phone folded, sliding it up with easing. If it was put away unfolded, it automatically runs the normal unfolding animation after sliding into view. Pocketing first folds the inner display shut, then slides the phone down. The cover shows your inbox or selected conversation and supports reading, typing, quick replies, meetings and appointment tracking. **Fold/Unfold** stays immediately left of **×**. Unfolding shifts the phone right, then swings the cover left around the hinge. Conversations, drafts and the current app survive pocketing and folding. While a text field is focused, typing does not trigger game shortcuts. Tab and Shift+Tab move focus within the open phone. Escape or clicking outside the field leaves text editing; another Escape pockets the phone.

The unfolded app keeps **Marketplace**, **Messages** and **Sell** tabs along the bottom, including inside conversations. Each icon sits beside its label, centered together within the tab. The current tab title is centered in the top status row. Search, part-type filtering and price/newest sorting are always visible above a three-column marketplace; cheapest-first is the default. Filters survive navigation, and live stock updates preserve search focus. Unfolded conversations show contact and hardware details on the left with chat starting at the top of the right column; the folded cover shows only the active conversation. Back returns to the originating marketplace, listings page or inbox category. Pending, blocked, sold, private and waiting-for-buyer conversations expose only appropriate actions. **Sell** shows inline price controls and valuation advice for each spare. Buyers still haggle and require a physical handoff; price guides do not reveal private budgets.

The cover has **LuckyFold Duo** printed beneath its display. Screen corners follow the housing contour. The unfolded screen intentionally has failed pixel rows/columns in the lower-right. Their colours have a slight green tint, shift smoothly about once a second and react to presses; they never steal input. In conversations, the message box's upper edge sits behind the band, with input and Send text below it and to the right of the vertical stripe. Quick replies stay above the band and bottom navigation remains clear. Both physical halves share one responsive scale. Cover rendering and layout recover after interrupted pocket/reveal animations.

The casing and extruded side rails are authored procedural geometry; the fault reuses the existing PNG. Three original SVG tab icons and the feature-local phone theme are tracked in [`docs/asset_provenance.md`](docs/asset_provenance.md). See the [artist handoff](assets/ui/luckyfold/README.md) for the fault/layout contract and [third-party notices](docs/third_party_notices.md) for the fold study attribution.

## The loop

1. **Start a solo high-score run.** Choose a budget and CPU, GPU, Storage or Balanced benchmark objective. You spawn in a furnished house with your PC workbench. A visible old spare case lets you try selling immediately; it isn't cash until actually sold.
2. **Use your phone.** Unfold the LuckyFold Duo: **Marketplace** shows social-classifieds listing tiles, **Messages** holds individual conversations, and **Sell** lets you list owned spare parts. Hardware notes help you match sockets, memory and power; sellers aren't all experts. Fold it closed for quick messages.
3. **Negotiate price, place and time.** There's no checkout or Buy button. Ordinary-person sellers and buyers can counter, refuse, get impatient or be unsure about technical questions. Each contact has different daytime/evening availability and two possible meeting locations. Ask naturally, then use the canonical pickup-time quick choices after agreeing a price.
4. **Check the confirmed meeting.** Agreeing only a price isn't enough. A confirmed appointment shows its **day, time, place and window end**. Track it from the conversation or map. A proposal is not confirmation. An agreement also isn't an exclusive reservation: shared stock still goes to the first valid handoff.
5. **Go there yourself.** Walk through the home door, approach your car and press E. Starting the car costs $3 fuel. Drive around town, park, and walk to the contact. They appear during the agreed window; E transfers the part and payment only at the right place and time. Early? Wait. Missed them? Message to reschedule.
6. **Sell spares.** Post an inventory part and a buyer will open with an offer. Negotiate in Messages, agree a meeting and physically hand it over to receive money. A live listing locks the part from installation; cancelling unlocks it. Installed/destroyed parts can't be listed, and handoffs can't pay twice.
7. **Build at home.** Return to your workbench and assemble case → compatible motherboard → CPU/RAM/graphics/PSU/storage through their minigames. Graphics can come from a discrete card or a CPU with integrated graphics plus a board with video outputs. Wrong purchase? Sell it or swap in compatible hardware.
8. **Tune and benchmark.** CPU/GPU/RAM clock and voltage settings can improve performance, destabilize it, overload the PSU or permanently destroy a part. Finish beside the home workbench. Incomplete rigs score zero with reasons; solo best scores persist locally.

## Clock and appointments

Runs default to **Day 1, 08:00 through Day 2, 22:00**, or **50 minutes 40 seconds** at **0.75 game minutes per real second**, before waits, activity time costs or finishing early. Choose **1–7 game days** in setup; one day retains the original 18-minute-40-second clock. Market refreshes happen every game hour. Return home around **19:00 on the final day** for assembly and tuning. Reminders appear with three game hours and one game hour left. The HUD shows game time and approximate real time remaining; hover the clock for the deadline.

Contacts offer a small set of upcoming feasible windows, generally up to 90 game minutes long, all bounded by the run's deadline. A new meeting must start **at least one game hour after confirmation**; old proposals are revalidated, but already confirmed meetings remain valid as their time approaches. Different characters prefer different hours and meeting places. New listings and buyers use contacts who still have a feasible window; when none remain, posting a sale is refused without taking the part. Overlapping appointments cannot place the same person at different locations. NPCs currently appear at meetings rather than simulating a full commute/work/home life.

## Multiplayer and exports

Multiplayer is disabled; local solo high scores are the game mode. The former ENet transport and lobby code remain for reference but cannot be entered through the menu or connection methods.

Windows and Web export presets/templates are not configured yet. Source inspection alone is not proof of an exported build working. Release packaging must exclude local credentials, development tools and test artifacts; browser exports also need an actual browser smoke test.

## Prototype notes

The world uses the supplied pixel-art pack, with the original atlas retained for characters. See [`assets/town/README.md`](assets/town/README.md) for asset wiring. Car controls are simple top-down directional driving, not a vehicle physics simulator. Hardware and benchmarks are fictional. Voltage is a **normalized game multiplier**, not real-world advice: **above 1.40× permanently destroys the component**.

There is no AI rival PC builder in solo; it remains a high-score challenge. LLM dialogue can sometimes be imperfect: use the game's explicit price/meeting status, not a vague chat promise, to check whether a transaction is actually agreed.

See [`docs/backend.md`](docs/backend.md) for state ownership and trading rules.

## Validation

Validation uses Godot 4.7.2: editor import/parsing, the offline regression suite and isolated native UI/gameplay smoke scenarios. Tests exercise gameplay outcomes, authored content and screen lifecycle, disable paid dialogue calls, and use isolated score files. The runner prints the current check count.

```sh
godot --headless --path . --editor --import --quit
godot --headless --path . --script res://tests/run_tests.gd
```

Windows regression/log runner:

```powershell
./tests/run.ps1 -Godot 'C:/path/to/Godot_console.exe'
```

Rendered UI and minigame checks should cover both 1440×900 and 1152×720. Live-provider conversation quality requires separate, bounded real-service testing; offline checks cannot establish it. Legacy LAN smoke scripts do not apply while multiplayer is disabled.
