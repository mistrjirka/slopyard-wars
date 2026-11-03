# Slopyard Wars

A **Godot 4.7** used-PC-building race inspired by *Scrapyard Wars*. Start at home, message local sellers on your phone, drive to appointments, build a compatible computer and overclock it before the three-day deadline.

## Run

Open `project.godot` in Godot 4.7 and press **F5**, or:

```sh
godot --path .
```

A 1440×900 window is recommended; 1280×720 is supported. No Python/Node server is required to play. The existing Godot AI addon is preserved but an MCP connection isn't needed for gameplay.

### Live marketplace characters

Launch Godot from a shell containing `OPENROUTER_API_KEY`. Only the solo process / LAN host makes OpenRouter requests, using **`inclusionai/ling-3.0-flash`**. Provider usage charges apply. Never put the key in project files or an exported build.

Without a key, or on a provider failure, clearly marked **offline** replies keep the trading loop playable. The fallback understands fewer natural-language variations. The game, not the model, owns money, inventory, schedules and transaction validation.

## Controls

| Control | Action |
|---|---|
| **WASD / arrow keys** | Walk; drive while in your car |
| **E** | Use home door; enter car; park/get out; complete a nearby scheduled handoff; use home workbench |
| **P / Tab** | Open or pocket your phone |
| **M** | Town overview and appointment tracking |
| **B / T** | Assembly / overclocking, only beside the workbench inside your house |
| **Space** | Intentionally wait in solo: 30 game minutes, or up to two hours toward a nearby upcoming meeting |
| **Esc** | Close phone, map, workbench or current dialog |

Movement stops while an interface is open. The world clock does **not** pause while you chat. Waiting cannot skip time for other LAN players.

Assembly uses clicks, dragging, cable matching, and **R/E/right-click** rotation where instructed. Overclock dials accept dragging, scrolling and focused arrow-key adjustments.

## The loop

1. **Start solo or host/join LAN.** Choose a budget and CPU, GPU, Storage or Balanced benchmark objective. You spawn in a furnished house with your PC workbench. A visible old spare case lets you try selling immediately; it isn't cash until actually sold.
2. **Use your phone.** **Browse** shows social-classifieds listing tiles, **Messages** holds individual conversations, and **Sell** lets you list owned spare parts. Hardware notes help you match sockets, memory and power; sellers aren't all experts.
3. **Negotiate price, place and time.** There's no checkout or Buy button. Ordinary-person sellers and buyers can counter, refuse, get impatient or be unsure about technical questions. Each contact has different daytime/evening availability and two possible meeting locations. Ask naturally or use the meeting-suggestion messages.
4. **Check the confirmed meeting.** Agreeing only a price isn't enough. A confirmed appointment shows its **day, time, place and window end**. Track it from the conversation or map. A proposal is not confirmation. An agreement also isn't an exclusive reservation: shared stock still goes to the first valid handoff.
5. **Go there yourself.** Walk through the home door, approach your car and press E. Starting the car costs $3 fuel. Drive around town, park, and walk to the contact. They appear during the agreed window; E transfers the part and payment only at the right place and time. Early? Wait. Missed them? Message to reschedule.
6. **Sell spares.** Post an inventory part and a buyer will open with an offer. Negotiate in Messages, agree a meeting and physically hand it over to receive money. A live listing locks the part from installation; cancelling unlocks it. Installed/destroyed parts can't be listed, and handoffs can't pay twice.
7. **Build at home.** Return to your workbench and assemble case → compatible motherboard → CPU/RAM/graphics/PSU/storage through their minigames. Graphics can come from a discrete card or a CPU with integrated graphics plus a board with video outputs. Wrong purchase? Sell it or swap in compatible hardware.
8. **Tune and benchmark.** CPU/GPU/RAM clock and voltage settings can improve performance, destabilize it, overload the PSU or permanently destroy a part. Finish beside the home workbench. Incomplete rigs score zero with reasons; solo best scores persist locally.

## Clock and appointments

The run starts **Day 1 at 08:00** and ends **Day 4 at 08:00**: three complete days. At two game minutes per real second, a day is about **12 real minutes**, or **36 minutes for the full run**, before intentional solo waits. Day/night tint and local appointments take inspiration from compressed-time life games; this is not an exact reproduction of *Schedule I*.

Contacts offer a small set of upcoming feasible windows, generally up to 90 game minutes long. Different characters prefer different hours and meeting places. Overlapping appointments cannot place the same person at different locations. NPCs currently appear at meetings rather than simulating a full commute/work/home life.

## Multiplayer

- Up to **4 players**, ENet **UDP 24680**. Join the host's LAN address before the match starts. Use `127.0.0.1` for two instances on one machine.
- The host owns movement/collision, time, availability, cash, parts and handoffs; clients send directional/action intents, not teleport coordinates.
- Players have their own car and rig; nearby peers and active contacts are visible. The small home layout is shared rather than separate customizable houses.
- Public matchmaking, NAT traversal, reconnect and unfinished-match saves aren't implemented. Separate-machine LAN connectivity has not been verified.

## Prototype notes

The world and sprite atlas are original, code-authored retro pixel art—no Pokémon/Nintendo assets. Car controls are simple top-down directional driving, not a vehicle physics simulator. Hardware and benchmarks are fictional. Voltage is a **normalized game multiplier**, not real-world advice: **above 1.40× permanently destroys the component**.

There is no AI rival PC builder in solo; it remains a high-score challenge. LLM dialogue can sometimes be imperfect: use the game's explicit price/meeting status, not a vague chat promise, to check whether a transaction is actually agreed.

See [`docs/backend.md`](docs/backend.md) for state ownership and trading rules.

## Validation

Focused real-model checks exercised buying and NPC-buyer price negotiation, meeting proposals/acceptance and canonical persisted appointments. A rendered pointer/keyboard playthrough covered home spawn, leaving home, entering and driving the car, phone negotiation, waiting for a contact, buying, listing a spare, a buyer's counteroffer, driving to and completing the sale, returning home and using the workbench. Host-rule smoke checks covered early/distant/duplicate handoff refusal. Additional scope and current checks are recorded in `docs/backend.md`. No automated test suite was added or run.
