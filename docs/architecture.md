# Architecture and extension guide

The project targets Godot 4.7 and prioritizes solo. LAN is an optional transport around the same simulation. Open `project.godot` and run `src/main.tscn` as before.

## Module map

| Folder | Responsibility |
| --- | --- |
| `src/core/` | Session lifecycle, clock, defaults, persistence and command routing |
| `src/network/` | ENet adapter and per-player snapshot filtering |
| `src/data/` | Typed hardware, character and activity Resources; catalogue and factual hardware notes |
| `src/trading/` | Stock, appointments, transactions, dialogue and phone |
| `src/world/` | Geometry, movement, encounters, pixel viewport, scenery and map |
| `src/workshop/` | Pure rig rules, workbench actions, assembly and tuning |
| `src/ui/` | Screen scenes, composition root, dialogs, toasts, theme and artwork |
| `resources/hardware.tres` | 75 editable hardware definitions, including tuning and reliability characteristics |
| `resources/characters.tres` | 12 character prompts, traits, negotiation preferences, schedules and offline lines |
| `resources/world_activities.tres` | Five encounter locations, costs, rewards and dialogue |
| `tests/` | Offline regression suite and optional two-process LAN smoke test |

`src/main.tscn` and its colocated `src/main.gd` form the composition root. The script mounts one independent screen scene for the current phase and connects its signals. Leaving a screen frees its subtree. Fixed layouts and repeated UI elements are authored as `.tscn` scenes beside their feature scripts, including phone pages, listing/message/inventory cards, workshop views, dialogs and result rows. Scripts bind state, connect behavior and instantiate templates for dynamic content; add a scene instance to the tree before calling setup methods that use its `@onready` children. Shared styling is the editor-visible `resources/ui/game_theme.tres`; the phone app has its own `resources/ui/phone_theme.tres`, explicitly bound across its capture SubViewport. UI fonts retain antialiasing. Custom world labels use the native 8px Pixel Operator 8 cut; the screen-resolution overview uses native 16px Pixel Operator. Both use aliased, whole-pixel rendering rather than shrinking UI fonts.

## Ownership

```text
Screen -> Game.act(command, payload)
                  |
       solo/host: command routing
       LAN client: LanTransport -> host command routing
                  |
       Movement / Market / Dialogue / Workshop / Activity systems
                  |
       session state -> changed signal -> screen refresh
                  |
       Snapshot.for_player -> LanTransport -> remote session
```

`Game` remains the single autoload, implemented by `game_session.gd`. It owns the match and explicitly constructs its systems. Systems are `RefCounted` objects with an injected session reference; they do not locate nodes through paths or reach into screen trees. The HTTP provider and transport are child Nodes because they need engine services. Their signals connect at the session boundary.

Runtime player/listing state deliberately remains serializable dictionaries: they form the wire payload without shipping Resources over RPC. `state_factory.gd` creates fresh nested containers for each player/run, including blessings, activity visits and serviced-item identities. Hardware, characters and activities are typed, editor-authored Resources; listing generation copies hardware values and character identity into runtime items. Never mutate shared Resources during a match.

Views read state and submit commands. Cash, inventory, appointments and final player positions belong to the authority, including in solo. Movement uses fixed physics ticks and collision substeps; clients send directions. The LAN adapter contains no trading or rig rules. Snapshot filtering deep-copies data before removing private fields.

The LuckyFold Duo separates its device shell (`src/trading/luckyfold_shell.gd`) from app/navigation state (`phone.gd`). Folding is local presentation state, with one selected listing and per-listing draft store shared by both modes. Both composers use `Game.act("chat")`; folding does not create a second chat or change trading rules. A weak reference protects deferred scroll-to-bottom work when a page is disposed during rapid folding/navigation. The shell preloads two replaceable PNGs and keeps its brand label as live text. Its decorative layers ignore mouse input.

The phone delegates browsing to `marketplace_view.gd` and selling help to `sell_view.gd`. `marketplace_query.gd` owns pure filtering/sorting without mutating shared stock. `hardware_stats.gd` supplies public sale estimates independently of private buyer budgets. The controller preserves filters, per-part price/expansion drafts, conversation drafts, detail-view state and the originating back destination. Live browse refreshes update cards without rebuilding the focused search control. Top-level navigation sits below the app body and hides inside a conversation. Unfolded conversations show a shared inbox-row sidebar on the left and the selected chat/details on the right; folded conversations show only the selected chat. The message composer retains its authored damaged-display clearance. Pocketing preserves the current fold mode. A transient capture SubViewport and authored chassis polygons project a solid hinged fold, while cancellation generations prevent stale captures from starting a later transition. `game_config.gd` supplies the one-day clock and deadline to the session, appointment rules and UI; new contacts must still have a usable window that day.

Pure rules in `rig_rules.gd`, `overclock_rules.gd`, `hardware_stats.gd`, `trade_rules.gd` and `world_rules.gd` have no scene-tree dependencies. The tuning UI, benchmark and host damage calculation share `Overclock.evaluate`; only the workshop authority rolls random damage. `Workshop.final_score` performs inherent CPU/GPU reliability checks once in a shared, deterministic test order (including connector fires), also on deadline/disconnect; `preview_score` is always pure. Market valuations calculate from current condition, avoiding stale cached prices. Keep new compatibility, scoring and geometry rules in these modules so tests need no screen.

## Extending the game

- **Content:** follow [content_authoring.md](content_authoring.md). Edit the three `.tres` catalogues in Godot's Inspector or a text editor. Stable IDs link character identities, salvage pools and service histories; display names may change independently.
- **Characters:** prompts shape voice; explicit resource fields shape prices and schedules. Provider replies propose decisions; the host still validates transactions.
- **Activities:** use an existing `kind` to add a stop through data alone. A new mechanic belongs in `ActivitySystem`, routed through `world_activity`, with costs and eligibility validated before mutation. Solo advances time; LAN uses the player's busy timer.
- **Match balance:** edit `game_config.gd`; player-facing budget/objective descriptions live in `match_setup.gd`.
- **Controls:** use Project Settings → Input Map. World actions use named actions; assembly retains focused pointer/rotation controls.
- **Screens:** create a scene/script beside its feature and wire outgoing signals in `src/main.gd`. Reuse the dialog and toast controls.
- **Town:** keep `world_rules.gd` collision bounds and `world_backdrop.gd` visuals aligned. `Catalog.LOCATIONS` supplies canonical meeting coordinates to schedules and the map.
- **Art:** register explicit preloads in `art_library.gd`, keeping dependencies visible to Godot's importer/exporter. Use nearest filtering for pixel art.
- **Actions:** validate in the appropriate gameplay system and route through `Game.act`. Test accepted, rejected and repeated requests against cash, inventory or position consequences.

Static floors, roads, buildings and decoration use a cached draw list. Actors, camera and night tint update independently. Dynamic UI rows instantiate reusable scene templates; the assembly canvas, rotary dials, part artwork and town map retain custom drawing and input code inside scene-authored controls. This follows Godot's guidance on [scene organization](https://docs.godotengine.org/en/stable/tutorials/best_practices/scene_organization.html) and [project organization](https://docs.godotengine.org/en/stable/tutorials/best_practices/project_organization.html).

No unfinished-run save, reconnect, client prediction, NPC commute simulation or solo AI builder was added. The optional Godot AI addon remains in `addons/`, disabled by default, with no runtime helper autoload in normal play.

## Validation

After a fresh checkout, import with `godot --headless --path . --editor --import --quit`, then:

```sh
godot --headless --path . --script res://tests/run_tests.gd
```

The Windows wrapper checks exit codes and logs for script errors:

```powershell
./tests/run.ps1 -Godot 'C:/path/to/Godot_console.exe' -IncludeLan
```

The regression suite disables online dialogue and uses `artifacts/test_scores.json`, leaving real player records alone. It covers Resources, graphics, compatibility, power, tuning, starter affordability, input bindings, movement, doors/cars, clock advancement, early/late/duplicate purchases, sale locking/credit, offline appointments, late replies, private snapshots, score parsing and screen/replay lifecycle. `content_tests.gd` adds per-model checks, per-character prompt/schedule checks, seeded damage/survival outcomes, condition-based resale, blessing consumption, encounter costs/limits/proximity and the new interfaces. The LAN test launches two headless localhost peers and checks authoritative movement and privacy.

Logs/captures belong in `artifacts/`, excluded from Git and Godot imports. Headless UI lifecycle checks do not replace visual review: launch a fresh game after scene changes and inspect the menu, folded/unfolded phone, marketplace, messages and workshop. The regression suite runs offline; it does not establish live-provider authentication or separate-machine LAN connectivity.

`phone_tests.gd` mounts the actual LuckyFold controls in a SubViewport at 1280×720 and 1440×900. It checks content bounds, cover branding, fold transitions, draft/focus retention, offline messages, pending-reply protection, sold listings and page restoration. It makes no live-provider calls.
