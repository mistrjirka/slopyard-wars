# World and trading backend

See [architecture.md](architecture.md) for the module map and extension guide.

## Session and commands

`src/core/game_session.gd` is the `Game` autoload. It owns match identity, phase, clock and command routing. Signals remain `changed()` and `notice(message)`. Public entry points remain `solo`, `host`, `join_game`, `leave`, `start_match`, `me`, `local_id`, `is_host`, `seller_status`, compatibility/score queries and `act`.

`act` supports `move {direction}`, `interact`, `wait`, `chat {listing_id, text}`, `post_sale {item_id, price}`, `cancel_sale {listing_id}`, `handoff {listing_id}`, `install {item_id}`, `tune {category, clock, voltage, item_id?, risk_quote?}`, `world_activity {activity_id, item_id?}` and `finish`. Tuning dialogs submit item identity and quoted risk so the host can reject stale confirmations. Cleaning supplies the owned item's identity. Old timer-based travel and unused standalone market/drive widgets were removed.

The authority routes commands into Movement, Market, Dialogue, Workshop and Activity systems. Solo and LAN share validation. `LanTransport` owns ENet/RPC plumbing at a stable child path under Game and emits action/connection/snapshot signals; it cannot award money or parts.

## Clock and movement

A run lasts one day from 08:00 to 22:00: 840 game minutes at 0.75 game minutes per real second (18m 40s before skips). `GameConfig` owns start, duration, deadline and rate; appointments and UI use those values. The market refreshes every 60 game minutes. Crossing 180 or 60 remaining minutes emits a build reminder; these are advisory, with no forced shopping cutoff. Solo wait skips 30 minutes, or up to 120 toward a nearby appointment. All time advancement uses one path, so waiting also advances workbench jobs and market refreshes. LAN cannot skip shared time. Clients extrapolate clock/busy timers; only the authority refreshes listings and ends matches. Deadline finalization runs before any further market refresh.

Fixed physics ticks normalize input, discard stale input after 0.4 seconds and substep movement against shared geometry. Players walk at 78 world pixels/second; cars move at 190. Spatial snapshots are scheduled about every 80ms, with a one-second heartbeat. Overlays stop local movement while the clock continues.

Home is 384×256 and town is 1024×640. Doors, car and bench require proximity. Fuel costs $3 on entering the car. Parking searches for a clear pedestrian exit. Installation, tuning and finishing require home workbench proximity and an idle bench.

## Market and appointments

`market_system.gd` owns listing identities, private floors, starter anchors, refresh and physical handoffs. Starter anchors preserve affordable compatible stock. `trade_rules.gd` supplies contact-specific availability and canonical meeting IDs. `Catalog.LOCATIONS` supplies shared coordinates.

System listings have `owner: 0`; player listings have `owner` and the exact inventory `item_id`. A live sale locks that spare from installation and duplicate listing. Cancelling unlocks it. An NPC buyer has a private bounded budget and opens with a lower offer.

New stock and player-sale buyers are drawn only from characters with a feasible appointment before `GameConfig.DEADLINE`. No usable window means no fresh listing/buyer; failed posting leaves the spare untouched. Existing conversations can explain that no windows remain today.

`marketplace_query.gd` filters public available listings by category and case-insensitive name/seller/manufacturer search, then sorts a new array by price or descending listing identity. Equal prices use ascending identity for deterministic order. `marketplace_view.gd` retains its filter controls while refreshing cards, so typing focus survives stock changes. Phone state retains filters and asking-price drafts through navigation. `sell_view.gd` uses public `HardwareStats.sale_guide`: current condition-adjusted value, 100–115% suggested asks and an 80% quick-deal guide, clamped to the host's $1–$5,000 listing range. These are negotiation hints, never guaranteed offers or disclosures of buyer ceilings.

Marketplace cards also receive the current local player's state. Listings from a blocked character show a red `SELLER BLOCKED YOU` label and border, muted part art/pricing and a tooltip explaining that trading is unavailable for this run. The result count includes blocked matches. Cards remain openable to read the conversation, whose composer is locked. Relationship changes refresh these markers across all the character's listings without mutating shared stock or marking the seller blocked for other LAN players.

Accepted prices live in `offers`, outstanding prices in `counters`, proposals in `meeting_proposals`, and confirmed slots in `meetings`. Slots have `{id, place, start, end, pos, label}`. A proposal is not confirmation. Overlapping commitments cannot place one contact at two places. Price agreements do not reserve shared stock.

A handoff checks current player/listing, price, confirmed window, town area, not driving, and contact proximity within 28px. Purchases debit once and append one item; public price drops are honored. Sales remove the exact owned item and credit once. The listing becomes sold in the same synchronous action, preventing repeated/competing transfers. Early, missed, distant and unavailable meetings transfer nothing.

## Dialogue and privacy

Dialogue delivery uses host-owned pending jobs with a `deliver_at` game-clock timestamp. Fast provider results are held until the character's authored delay expires; slow results deliver when ready. Solo waits advance these delays, and LAN clients receive only the resulting chat snapshots. Pending jobs are cleared with the match lifecycle. Tests use zero delay for legacy trading fixtures and explicitly exercise delayed delivery separately.

Player-sale leads are held in `Market.sale_interest`, outside replicated state. Listings expose only `buyer_contacted`; before that, Sell shows waiting for interest and offers no phantom buyer conversation. Price-sensitive interest can be delayed or absent. Due leads validate listing status, match identity, player readiness, contact refusal and remaining appointment availability before sending one opening message.

`contact_relationships.gd` owns deterministic social rules keyed by stable character ID under each player's `contact_relations`. The authority checks grounded lowball offers, explicit insults and repeated messages, and enforces authored conversation preferences before accepting prices. Refusal clears existing agreements and blocks future chat/handoffs across that contact's listings for this player. Snapshots erase other players' relationship histories. Resources supply patience, hobby topics, invitation/warning/refusal text and biographies; model output cannot directly modify this state.

The provider receives the actual offence count and proposes `contact_action=none|warn|block` alongside its dialogue. A block proposal takes effect immediately, including on the first offence. The host also blocks direct insults, the first extreme lowball when `block_on_lowball` is enabled, and explicit dismissals matching the character's authored `sensitive_topics`. Personal-boundary prose guides the model on contextual variants; the deterministic topic check does not depend on model cooperation. Milder irritations accumulate toward `patience_limit`, currently two for the roster. Model warnings and deterministic offences on the same turn count only once. Explicit price offers are checked using both the grounded decision and the offline parser, so a model asking for confirmation cannot postpone an obvious lowball block. Short follow-ups such as "I said 100" and bare "100" also count; technical numbers inside ordinary questions do not. Blocks are permanent for the run and take priority over any simultaneous deal or meeting proposal. A valid model farewell is preserved, followed by an explicit system block notice. Both phone modes disable the composer, Send and quick replies on every listing from the blocked character.

Before the provider call, `Relationships.preview` assesses a copy of relationship state only, without counting an offence or creating rapport in live state. A predicted block supplies `required_refusal_reason` to generation. The normal response path still assesses and applies the actual block exactly once. This lets the same provider request generate an offence-specific farewell rather than paying for a second rewrite. If the model fails to return a consistent block decision, `refusal_by_reason` selects the character's hobby, lowball or conduct fallback. Literal topic matching is not required for semantic model refusals; the model is explicitly instructed to understand paraphrases and references from recent history. Six live cases verified three previously unseen indirect hobby insults, an explicit dismissal, a lowball and a polite non-blocking control; this is sample evidence, not a guarantee of perfect interpretation.

`seller_service.gd` proposes bounded decisions via OpenRouter or its marked offline fallback. `resources/characters.tres` supplies each character's system prompt, interests, pet peeves, expertise and offline voice; price preferences and schedules also come from those Resources. Verified hardware notes are included in the prompt. Only host/solo reads `OPENROUTER_API_KEY`. Live dialogue uses `deepseek/deepseek-v4.1-flash-1017` with reasoning disabled; model output cannot directly mutate money, inventory or schedules.

`dialogue_system.gd` tracks jobs by monotonically increasing request IDs and match identity. It validates grounded prices, prior counters, buyer ceilings/seller floors, availability and canonical slots. Leaving, ending or replacing a match invalidates pending work. Every run has a fresh identity, including after returning to the menu.

Counter direction is also host-validated: if both a grounded human offer and the proposed counter are within the contact's limits, an NPC seller countering at or below that offer accepts the human's offered price instead. The reverse applies to an NPC buyer overbidding the human's ask. The reply uses the character's acceptance text and drops the proposed logistics so prose and state agree. Invalid or ungrounded amounts are not converted into agreements. This correction is independent of model choice.

An `accept_counter` decision is also rejected when the deterministic offer parser recognizes an explicit different price in the current message. For example, "Could you do $900?" is not agreement to an earlier $800 offer. Ordinary "yes/deal" acceptance remains supported. This catches clear price conflicts; it is not a complete natural-language verifier.

Provider limits: 12-second timeout, 400 output tokens with reasoning disabled, two concurrent and four queued requests, 60 requests per match, eight history messages and 240-character input. Visible replies remain capped at 320 characters. Tests force `online_enabled = false`; they require no credentials or paid requests. Credentials never enter state or snapshots. The service loads `OPENROUTER_API_KEY` first, with `.local/openrouter.cfg` (`[openrouter]`, `api_key`) as a project-local fallback. `.local/` is excluded by Git and contains `.gdignore` to keep it out of imports/exports.

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

### Live model comparison, 2026-11-09

A small opt-in comparison used five fixed cases per model: Bella's $900/fire-extinguisher offer, Bea's $340 counter to $385, Gus's "What?" clarification, a personal question to Bea, and an NPC buyer negotiating a human's $900 ask. These are single samples, not a statistical reliability benchmark. The prompt, character definitions, histories and tool schema came directly from `SellerService._body`; this evaluated raw model decisions before host repair. No default model was changed.

| Model | Observed behavior | Average request time | Estimated cost of 60 similar replies |
| --- | --- | --- | --- |
| [Ling 3.0 Flash](https://openrouter.ai/inclusionai/ling-3.0-flash) | Reproduced $900 -> $850 seller counter; disclosed "below my floor" in another case | 1.53s | $0.003 |
| [Claude Haiku 5.5](https://openrouter.ai/anthropic/claude-haiku-5.5) | Countered $950 rather than undercutting; mislabeled that offer as intent=none; often wordy and returned to selling during personal chat | 1.70s | $0.029 |
| [Gemini 3.8 Flash](https://openrouter.ai/google/gemini-3.8-flash) | Accepted $900, countered Bea's low offer at $375, explained the snail and answered the personal question | 2.93s | $0.104 |
| [Claude Sonnet 5.5](https://openrouter.ai/anthropic/claude-sonnet-5.5) | Accepted $900, held Bea's $385 and gave more characterful personal detail; required automatic tool choice | 2.37s | $0.556 |

Costs above extrapolate provider-reported usage for five successful replies each, including prompt tokens. Actual runs vary with history length, routing, caching, reasoning and prices; credit purchase fees are excluded. The tests used the existing 400-token/non-thinking settings for Ling and Haiku, and a 2048-token ceiling with low reasoning effort for Gemini and Sonnet. Unsupported temperature was omitted for Anthropic. Sonnet initially rejected all five forced-tool requests; repeating those five with `tool_choice=auto` produced tool calls. Its production integration would need that adaptation and continued validation of missing/malformed calls; see [Anthropic's tool-choice rules](https://platform.claude.com/docs/en/agents-and-tools/tool-use/define-tools).

Local ignored artifacts contain the opt-in harness (`artifacts/compare_dialogue_models.gd`, requires `-- --live`), original results (`artifacts/dialogue_model_comparison.json`) and Sonnet's adapted results (`artifacts/dialogue_model_sonnet_auto.json`). They contain dialogue and usage, not credentials. Ordinary regression tests never invoke this harness.

### Flash Lite follow-up and selected default

On the same day, eight fixed cases were run once each against `google/gemini-3.5-flash-lite` and `google/gemini-3.8-flash`, using low reasoning effort and a 2048-token output ceiling for both. The additional cases covered a technical question containing a price-like number, further haggling and acceptance of a proposed pickup slot. Results are in `artifacts/dialogue_gemini_comparison.json`; the opt-in harness flag is `-- --live --gemini-compare` (16 requests).

Flash Lite produced a false $800 acceptance when the human seller asked for $900, and reported a stale $340 offer in another reply. Its technical-question response also contained a spurious `<span></span>` meeting ID, though meeting_action=none prevented any appointment change. Its average latency was 1.74 seconds and measured cost was $0.0102036 for eight replies. Flash 3.8 kept the bargaining prices coherent in this sample; its average latency was 3.94 seconds (including one 10.1-second response) and measured cost was $0.0140565. Both returned tool-call JSON for all eight requests. This remains a small exploratory sample, not a reliability guarantee.

Extrapolated to 60 similar requests, that is about $0.077 for Lite versus $0.105 for 3.8. Lite saved about 27%, less than its input-token price alone suggests because it used more reasoning tokens. This comparison initially selected **Gemini 3.8 Flash**, subsequently replaced after the budget comparison below. [OpenRouter's Flash Lite listing](https://openrouter.ai/google/gemini-3.5-flash-lite) quotes standard pricing of $0.30/M input and $2.50/M output at the time of this comparison; actual provider usage is the basis for the costs above.

### Budget comparison and current default

The next comparison targeted roughly $0.03 per 60 similar replies. Eight fixed cases each were sent to two DeepSeek snapshots and Haiku 5.5, with reasoning disabled and a 400-token output ceiling. Haiku omitted the unsupported temperature parameter. Actual usage, including any automatic caching and the providers selected by OpenRouter, gave:

| Model | Average request time | Cost of eight requests | Extrapolated 60 replies |
| --- | --- | --- | --- |
| [DeepSeek V4.1 Flash 1017](https://openrouter.ai/deepseek/deepseek-v4.1-flash-1017) | 1.37s | $0.003554228 | $0.0267 |
| [DeepSeek V4 Flash 0731](https://openrouter.ai/deepseek/deepseek-v4-flash-0731) | 1.95s | $0.002489443 | $0.0187 |
| [Claude Haiku 5.5](https://openrouter.ai/anthropic/claude-haiku-5.5) | 1.63s | $0.003808900 | $0.0286 |

The current default is **DeepSeek V4.1 Flash 1017**, pinned to that snapshot. It accepted Bella's $900 offer, handled the reverse buyer negotiation, clarified Gus's snail reference and returned the canonical pickup ID. Its short personal replies read more naturally in this sample than Haiku's longer messages. One follow-up incorrectly reported the previous $340 offer as current; host amount grounding discards that stale intent while retaining a valid $385 counter. Haiku made the same stale-amount error and labeled Bella's explicit offer as intent=none. V4 Flash 0731 was cheaper but attached a new condition to an acceptance, making text and decision disagree. None is a guarantee of error-free dialogue; host checks remain necessary.

Four further messages through the actual game service confirmed the selected model's request format, parsing and validated prices without offline fallback. The ordinary regression suite passed 1,240 checks and both LAN smoke processes passed. The local harness flag is `-- --live --budget-compare` (24 requests), and its ignored result file is `artifacts/dialogue_budget_comparison.json`.

These estimates are observations, not a spending cap or promised per-game price. Context lengths, automatic cache hits, routing and provider prices can change costs. Reasoning is disabled and output limited to 400 tokens to keep the tested workload small; the existing 60-request match limit remains.

Godot 4.7.2 headless regression checks cover gameplay and screen lifecycle. A real two-process localhost ENet test covers client direction input, authoritative movement and filtered snapshots. See [architecture.md](architecture.md#validation) for commands and visual/live-provider/separate-machine testing limits.
