# Slopyard Wars

A playable **Godot 4.7** prototype inspired by the second-hand PC-building race in *Scrapyard Wars*. Three days. One budget. A shared used-parts market. Build the fastest rig you can before the clock runs out.

## Run

Open `project.godot` in Godot 4.7 and press **F5 (Run Project)**, or from this directory:

```sh
godot --path .
```

Mouse and keyboard; a 1440×900 window is recommended. No downloaded game assets or Python/Node service is needed. The existing Godot AI editor integration is preserved, but gameplay does not require an MCP connection.

### LLM sellers

Launch Godot from a shell that has `OPENROUTER_API_KEY` set. The solo player / LAN **host** makes requests to OpenRouter using `inclusionai/ling-3.0-flash`; joining players need no key. Requests incur your provider's normal usage charges. Do not put the key in project files, exported builds, screenshots, or Git.

Without a key, or if OpenRouter fails, the game remains playable with explicitly labeled **offline** seller dialogue. Price negotiation, inventory, compatibility and scoring always run in game code. Seller dialogue cannot award parts or change your balance.

## The race

1. **Start solo**, or host/join a LAN lobby. Choose the starting budget and benchmark objective.
2. **Shop the market.** Inspect specs, socket, memory generation, asking price and seller personality. New listings appear, old ones disappear and prices drop while you play.
3. **Negotiate.** Message the seller with your offer or agree to their counter; travel unlocks only after a confirmed chat agreement. An accepted offer is **not a reservation**.
4. **Drive to collect.** Pickups take simulated travel time and fuel. You pay for the part on arrival; the first player to arrive gets it. If someone beats you there, you keep the part money but lose your travel fuel.
5. **Assemble the rig.** Collect a case, PSU, CPU, compatible motherboard, RAM and HDD/SSD, plus either a graphics card or compatible integrated graphics. Fit the case and motherboard first, then complete the assembly interaction for each part.
6. **Tune carefully.** CPU, GPU and RAM have clock/voltage controls. These are normalized game multipliers, **not real-world hardware advice**. Too much clock is unstable; voltage **above 1.40× destroys the part permanently**. Buy a replacement if there is time.
7. **Benchmark.** Submit your build before the deadline. CPU, graphics, memory and storage contribute according to the selected objective. Incomplete/incompatible rigs score zero with reasons shown. Solo best scores are saved locally.

Three in-game days take approximately **12 real minutes**. The clock continues while shopping, chatting and building. Assembly and stress runs also make your workbench temporarily busy.

## Controls

- **Mouse:** select listings, send chat, agree a price, drive, and operate the workbench.
- **1–5:** switch between Classifieds, Drive, Workbench, Overclock and Guide (outside text fields).
- **Assembly:** follow the highlighted targets; click screws/clips, drag parts into position, and drag cables to matching sockets. **R/E/right-click** rotates a CPU or flips RAM; there is also a Rotate button. **Esc** cancels.
- **Overclock dials:** drag or scroll; focus a dial and use arrow keys for precise changes. Settings take effect only when you run the stress test.

## Multiplayer

- One player selects **Host**; others select **Join** and enter the host's LAN IP.
- ENet uses **UDP port 24680**, up to **4 players**. Allow that port through the host firewall. On one machine use `127.0.0.1` in the second instance.
- Join before the host starts the match. There is no public matchmaking, NAT traversal, dedicated-server setup or reconnect support in this prototype.
- All players see the same listings. The host owns the clock, purchases, inventory and benchmarks. Other players do not receive your private seller-chat history or offers.
- Finish early to lock your rig; results appear when everyone finishes or time expires.

## Prototype scope

This is a 2D strategy/workbench prototype, not yet a freely walkable 3D garage. Driving is a timed pickup route visualized on the city map, not a vehicle physics simulator. Hardware and benchmark numbers are fictional. Assembly interactions are a first pass intended for iteration. Solo is a high-score run; there is no AI rival builder yet. No save/resume of an unfinished match.

See [`docs/backend.md`](docs/backend.md) for scoring, compatibility, negotiation and seller-service limits.

## Validation

Earlier prototype validation on Godot 4.7.2 covered a full rendered solo run, live OpenRouter chat, six-part integrated-graphics assembly, safe overclocking and valid benchmark results, and layout at 1440×900 and 1280×720. The newer chat-agreement flow was checked through focused live model/runtime probes and an actual pointer-driven UI run: availability did not unlock pickup, a natural purchase message received seller acceptance, and the agreed pickup transferred the part. The updated tile-and-chat marketplace was inspected at 1440×900 and 1280×720. Additional runtime smoke checks exercised all seven assembly minigames, component destruction, and a contested purchase between two local ENet instances. The two-window UI host/join/start/wait/results flow was also exercised. Separate-machine LAN connectivity has not been verified. No automated test suite was added or run.
