# World and trading backend

See [architecture.md](architecture.md) for the module map and extension guide.

## Session and commands

`src/core/game_session.gd` is the `Game` autoload. It owns match identity, phase, clock and command routing. Signals remain `changed()` and `notice(message)`. Public entry points remain `solo`, `host`, `join_game`, `leave`, `start_match`, `me`, `local_id`, `is_host`, `seller_status`, compatibility/score queries and `act`.

`act` supports `move {direction}`, `interact`, `wait`, `chat {listing_id, text}`, `post_sale {item_id, price}`, `cancel_sale {listing_id}`, `handoff {listing_id}`, `install {item_id}`, `tune {category, clock, voltage, item_id?, risk_quote?}`, `world_activity {activity_id, item_id?}` and `finish`. Tuning dialogs submit item identity and quoted risk so the host can reject stale confirmations. Cleaning supplies the owned item's identity. Old timer-based travel and unused standalone market/drive widgets were removed.

The authority routes commands into Movement, Market, Dialogue, Workshop and Activity systems. Solo and LAN share validation. `LanTransport` owns ENet/RPC plumbing at a stable child path under Game and emits action/connection/snapshot signals; it cannot award money or parts.

## Clock and movement

A run lasts Day 1 at 08:00 to Day 4 at 08:00: 4,320 game minutes, at two game minutes per real second. Solo wait skips 30 minutes, or up to 120 toward a nearby appointment. All time advancement uses one path, so waiting also advances workbench jobs and market refreshes. LAN cannot skip shared time. Clients extrapolate clock/busy timers; only the authority refreshes listings and ends matches.

Fixed physics ticks normalize input, discard stale input after 0.4 seconds and substep movement against shared geometry. Players walk at 78 world pixels/second; cars move at 190. Spatial snapshots are scheduled about every 80ms, with a one-second heartbeat. Overlays stop local movement while the clock continues.

Home is 384×256 and town is 1024×640. Doors, car and bench require proximity. Fuel costs $3 on entering the car. Parking searches for a clear pedestrian exit. Installation, tuning and finishing require home workbench proximity and an idle bench.

## Market and appointments

`market_system.gd` owns listing identities, private floors, starter anchors, refresh and physical handoffs. Starter anchors preserve affordable compatible stock. `trade_rules.gd` supplies contact-specific availability and canonical meeting IDs. `Catalog.LOCATIONS` supplies shared coordinates.

System listings have `owner: 0`; player listings have `owner` and the exact inventory `item_id`. A live sale locks that spare from installation and duplicate listing. Cancelling unlocks it. An NPC buyer has a private bounded budget and opens with a lower offer.

Accepted prices live in `offers`, outstanding prices in `counters`, proposals in `meeting_proposals`, and confirmed slots in `meetings`. Slots have `{id, place, start, end, pos, label}`. A proposal is not confirmation. Overlapping commitments cannot place one contact at two places. Price agreements do not reserve shared stock.

A handoff checks current player/listing, price, confirmed window, town area, not driving, and contact proximity within 28px. Purchases debit once and append one item; public price drops are honored. Sales remove the exact owned item and credit once. The listing becomes sold in the same synchronous action, preventing repeated/competing transfers. Early, missed, distant and unavailable meetings transfer nothing.

## Dialogue and privacy

`seller_service.gd` proposes bounded decisions via OpenRouter or its marked offline fallback. `resources/characters.tres` supplies each character's system prompt, interests, pet peeves, expertise and offline voice; price preferences and schedules also come from those Resources. Verified hardware notes are included in the prompt. Only host/solo reads `OPENROUTER_API_KEY`. The existing `inclusionai/ling-3.0-flash` integration remains; model output cannot directly mutate money, inventory or schedules.

`dialogue_system.gd` tracks jobs by monotonically increasing request IDs and match identity. It validates grounded prices, prior counters, buyer ceilings/seller floors, availability and canonical slots. Leaving, ending or replacing a match invalidates pending work. Every run has a fresh identity, including after returning to the menu.

Provider limits remain: 12-second timeout, 400 output tokens, two concurrent and four queued requests, 60 requests per match, eight history messages and 240-character input. Tests force `online_enabled = false`; they require no credentials or paid requests. Credentials never enter state or snapshots.

`network/snapshot.gd` removes other players' chats, offers, counters, proposals and private buyer limits from a deep copy. Confirmed meetings/spatial state remain visible for rendering.

## Building and scores

`resources/hardware.tres` contains typed definitions. `rig_rules.gd` owns socket, form-factor, memory, integrated graphics, power and scoring rules. `workshop_system.gd` applies installation/tuning and returns swapped parts to inventory.

Installation costs 10 game minutes; stress testing costs 20. Clock/voltage are normalized 1.00–1.60 game multipliers. `overclock_rules.gd` evaluates model headroom, condition, voltage tolerance, heat load, case airflow, board VRMs, PSU regulation and cooling upgrades. UI previews and scoring use the same pure evaluator. Excess clock reduces performance; voltage, heat and clock stress create a visible destruction probability. The host rolls once per submitted test. Survivors lose condition according to risk; failures permanently remove the part. Normal models have zero-risk stock and safe presets. An authored `stock_failure_chance` adds an independent, condition-adjusted reliability risk; it remains at stock. Voltage above 1.40 guarantees destruction regardless of modifiers. Incomplete, incompatible or overloaded builds score zero.

Valid builds with inherently risky hardware receive final tests through `Workshop.final_score`, including at the deadline and on disconnect. The player's `benchmark_checked` flag prevents rerolls when explicit finishing is followed by match completion. A pure `Overclock.final_tests` plan is shared by the dialog and host: CPU then GPU then RAM, only for authored inherent risks. The first eligible test consumes the one Lucky blessing; later tests quote unblessed odds. Execution stops if a failed component prevents the rig from running. Tests apply wear on survival or remove the failed part, then score the result (including integrated-graphics fallback). A single host roll selects fire, other damage or survival; fire probability is a subset of total destruction. `last_stress_test.failure_mode` and the event log identify connector fires. The finish dialog states the actual risk. A score preview never rolls damage. See [content_authoring.md](content_authoring.md#model-reliability) for the fictional model rates and reference.

Condition scales stock score and used-price guidance. Resale offers read current condition when posted. Tuning previews calculate the score after wear on a copy; previewing cannot mutate owned hardware.

## World encounters

`resources/world_activities.tres` defines the five stops. `activity_system.gd` validates proximity, parked status, busy/ready status, money, time and repeat limits before changing state. Cleaning also requires a real, unlisted, unserviced owned part; salvage selects a valid stable model ID and allocates a unique item identity. The authority charges and grants synchronously, so duplicate requests cannot claim limited rewards twice.

Lucky's shrine costs $5 and five game minutes, once per game day. It grants one unstackable `lucky_tests` charge. The next test with nonzero risk at or below the hard voltage limit consumes it and multiplies failure probability by 0.75. Safe tests preserve it. `cooling_bonus`, visits and serviced-item identities belong to the player and reset for a fresh run. Solo encounter costs advance the shared time path; LAN sets a personal busy timer instead of skipping everyone else's time.

Solo records remain at `user://highscore.json`, isolated behind `score_store.gd`. Loading rejects non-numeric scores and clamps negatives. Tests redirect score I/O to `artifacts/`. Unfinished-run persistence is not implemented.

## Verification

Godot 4.7.2 headless regression checks cover gameplay and screen lifecycle. A real two-process localhost ENet test covers client direction input, authoritative movement and filtered snapshots. See [architecture.md](architecture.md#validation) for commands and visual/live-provider/separate-machine testing limits.
