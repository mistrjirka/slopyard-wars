# World and trading backend

## Owners

- `scripts/game.gd` (`Game` autoload): authoritative match, clock, movement, inventory, listing ownership, chat decisions, appointments and transactions. Public signals remain `changed()` and `notice(message)`.
- `scripts/world_rules.gd`: shared home/town bounds, solid geometry, spawn/door/car/workbench locations and collision-aware motion. Rendering and host movement use the same shapes; clients never supply final coordinates.
- `scripts/trade_rules.gd`: contact availability, eligible places, finite upcoming meeting choices and day/time formatting. `Catalog.LOCATIONS` is the sole meeting-place coordinate map.
- `scripts/seller_service.gd`: bounded OpenRouter counterparty dialogue/decision proposals and a clearly marked offline fallback. The model cannot directly change inventory or balances.
- `scripts/town_view.gd`, `town_map.gd`: pixel-world and read-only town overview.
- `scripts/phone.gd`: Browse / Messages / Sell UI. `main.gd` owns overlays/input and reuses existing assembly, workbench, tuning and results components.

The old standalone `market_view.gd` / `drive_view.gd` widgets remain unused in the repository; their old travel action cannot bypass the new physical world. The active entry point is still `scenes/main.tscn`.

## Time and spatial state

`remaining` is game minutes until the three-day deadline, initially 4320. `Game.clock()` returns absolute minutes starting Day 1 08:00 (480). Rate is 2 game minutes per real second; Day 4 08:00 ends the run. Clients extrapolate the clock between host snapshots. Solo `wait` intentionally advances 30 minutes, or up to 120 toward a nearby appointment. LAN wait cannot skip shared time.

Player state adds `area` (`home`/`town`), `pos`, `car_pos`, `driving`, `facing`, `meetings` and `meeting_proposals`. The host consumes bounded normalized directional input and stops stale input after 0.4 seconds. Foot speed is 78 world pixels/sec, car speed 190. The host substeps motion against solid shapes and broadcasts spatial snapshots about every 80ms. There is no client prediction yet.

Home is a 384×256 room and the town is 1024×640. E transitions only near the door, enters a nearby car for $3, parks/exits where there is space, or trades with a scheduled nearby contact. Installation, tuning and finishing require home workbench proximity. Opening phone/workbench/map stops local movement input but not time.

## Buying and selling

Existing `solo/host/join_game/leave/start_match/me/local_id/is_host`, compatibility, score and seller-status helpers remain. `Game.act` now supports:

- `move {direction: Vector2}`, `interact {}`, `wait {}`;
- `chat {listing_id, text}` for both sellers and NPC buyers;
- `post_sale {item_id, price}` and `cancel_sale {listing_id}`;
- `handoff {listing_id}` (also invoked by E near the contact);
- `install {item_id}`, `tune {category, clock, voltage}`, `finish {}`.

Legacy `travel` is refused: no timed automatic pickup or teleport remains. There is no numeric purchase-offer action.

System listings have `owner: 0`. Player listings have the player ID in `owner`, the inventory identity in `item_id`, and one NPC buyer contact. The host generates a private bounded buyer budget relative to the item's used price; the buyer opens with a lower offer, and the actual LLM handles subsequent negotiation. The listed item stays in inventory but is locked from installation and duplicate listing until cancelled or sold. Each fresh player has one explicitly named old spare case so Sell is usable immediately.

`offers` contains accepted prices, `counters` outstanding counterparty prices. Neither gives a reservation. `meeting_proposals` contains suggested canonical slots; `meetings` contains confirmed slots `{id, place, start, end, pos, label}`. `active_meetings(player)` decorates these with listing/contact identity, buy/sell side and early/now/missed status.

The service receives only valid upcoming meeting choices and its previous proposal. The host matches the returned ID to its own data, refuses stale/end-past slots, and rechecks overlapping appointments at other locations for the same contact. Price plus an explicit accepted meeting is required. Meetings protect system listings from incidental expiry during their window; another player can still complete a valid competing handoff first.

A handoff checks current player, listing, accepted price, confirmed time window, town area, not driving, and ≤28px contact proximity. Purchases debit once and transfer one listing to inventory; public price reductions are honored. Sales remove the exact still-owned listed item and credit once. The listing becomes sold atomically before another intent can transfer it. Cancelled/missing/expired listings cannot transfer. Early/late/distant handoffs don't change cash or inventory. Missed appointments can be renegotiated while the listing remains available.

The availability owner assigns stable contact-specific hour windows and two eligible places. NPCs materialize for active appointments, not full autonomous commute simulation. All valid active contacts and nearby peers are rendered in the shared town.

## Seller service

The host uses `inclusionai/ling-3.0-flash` with native forced `market_reply` function output. This is a decision proposal tool, not a money-transfer tool. Its schema carries dialogue, human price intent/amount, counterparty price action/counter amount and meeting action/canonical ID. The same contract supports an NPC seller or an NPC buyer; concrete role examples prevent reversing buyer/seller price fields.

The host validates message-grounded prices, prior counters, seller floor / NPC buyer ceiling, stock, player/match identity and meeting choices. Availability/spec questions alone don't authorize purchases. Logistics can reaffirm an existing accepted price without manufacturing another price agreement. A provider's known `accept` intent synonym is normalized to an offer but must still pass the same host grounding.

Requests have a 12-second timeout, max 400 output tokens, reasoning disabled, 2 concurrent plus 4 queued, a per-match request budget, bounded 8-message history and 240-character buyer input. Failures show offline status/replies. Queued work and late replies are cancelled/discarded after leaving, match end, removed players or unavailable listings. Keys stay out of snapshots/logs/files. `last_response` stores only the last bounded dialogue/function JSON and finish reason for local diagnostics, never credentials or reasoning; it is not replicated.

Other players' chats/offers/counters/proposals and private buyer budgets are stripped from network snapshots. Confirmed meetings/spatial state are visible to peers for rendering. No production abuse-rate limiting, reconnect or dedicated-server lifecycle is promised.

## Building and scores

Sockets OX3/OX4/NX5, DDR3/4/5 and ATX/mATX compatibility are unchanged. Case then board precede remaining components; graphics can be CPU integrated graphics with board outputs. PSU must cover tuned draw. Installation costs 10 game minutes of workbench busy time; stress testing 20. Clock and voltage are normalized 1.00–1.60; voltage >1.40 destroys a part. Stable clock = 1 + 1.3·(V−1); excess clock reduces performance. Scores and objective weighting remain in `catalog.gd`; invalid builds score zero. Solo bests remain in `user://highscore.json`.

## Validation and limits

Actual native-model responses and persisted outcomes were inspected for buying, counterpart buyer negotiation and meeting confirmation. A disposable host-rule smoke verified no transfer from home or before the appointment and exactly-once sale credit/removal. A keyboard/pointer-rendered run completed both a purchase and sale through actual walking/driving, confirmed NPC presence, then returned home to the workbench and assembly. A two-process localhost ENet run confirmed both home spawn and host-authoritative client movement (192,180 → 272.6,180 on both peers); LAN waiting did not skip time. With the provider credential absent, offline chat still confirmed canonical appointments, a missed meeting charged nothing, rescheduling produced a new future window, duplicate listing/installation was refused, and cancelling unlocked installation. Current world/map/phone were rendered at 1440×900 and 1280×720. Godot 4.7.2 import/parsing and game logs were free of script errors; diff whitespace and credential scans were clean. Original prototype checks covered component burnout, valid benchmark scoring and contested ENet purchases; those older checks used timer-based trips, not the new physical handoff.

The pixel town, movement/collision, phone, schedule and trade paths are a first playable pass. Contacts may phrase logistics imperfectly; the explicit canonical meeting/status is authoritative. No unfinished-match persistence, police/traffic, advanced vehicle dynamics or fully simulated NPC daily movement. No automated suites were created or run.
