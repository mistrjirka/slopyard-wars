# PC installation minigames — recovered agreement

## Goal and constraints

Make installing a PC a clear, physically understandable sequence, available only when the required parts are actually fitted. This records the user's original installation request and subsequent corrections from the November 10 conversation; it is not a replacement design.

- Keep static controls/layout in authored Godot scenes; custom drawing is appropriate for the interactive assembly diagrams.
- Root assistant performs visual/image acceptance, as the user explicitly requested; subagents may implement or inspect source.
- Keep the workbench understandable, not overcomplicated. Show the current mistake, its actual penalty and how to correct it.
- Latest user clarification: the case tray and motherboard must use the **same orientation**. Each stage needs larger, short **DO / DON'T** instructions describing the action and the mistake to avoid.
- Coolers are supplied/expected with the CPU: **installation props only**, not separately purchased parts, marketplace listings, inventory slots or independent performance stats. This supersedes the earlier separate-cooler suggestion. Poor installation can still penalize the CPU.
- The oversized object reported separately was the **desk in the house**, not a request to shrink the minigame artwork.
- Preserve existing RAM/storage mechanics; their current detailed designs were not specified by the recovered request. Do not present invented additions as user requirements.

## Approach

### Installation prerequisites

- A motherboard requires an installed case; respect board/case form factors.
- CPU, GPU, RAM and storage require the case/motherboard chain; respect CPU socket and RAM compatibility.
- A PSU requires the case, not a motherboard.
- An invalid minigame must not open. Recheck current ownership, compatibility and availability at launch and at host-side installation; a disabled button alone is insufficient.

### Motherboard: standoffs, placement and fastening

1. Show a case tray with multiple possible mounting holes and the selected board's actual mounting-hole pattern. Use researched ATX/microATX references, not an invented uniform grid. Orient both identically with matching rear-I/O cues and hole identifiers; the lowered board's holes must coincide exactly with the tray supports. Do not leave a duplicate reference board under the draggable one.
2. Let the player install/remove standoffs only where the board needs support, then lower the board onto them.
3. Missing standoffs blink red at the unsupported board holes. An extra standoff **under the PCB where there is no mounting hole** also blinks red and remains visible through the board. Latest user clarification: extra standoffs outside the motherboard's footprint do not collide, incur **no penalty**, and must not block installation.
4. Missing supports must be corrected before successful fastening. Latest timing clarification: when tightening would pass **50%** with an unwanted standoff overlapping solid PCB, apply one damage strike, stop the screw at the resistance point, highlight the extra support red and block further tightening. Neither lowering the board nor choosing Start Screws alone causes this damage. Reuse the drawn board footprint for the collision decision.
5. Tell the player to back out the started screw, lift the board and remove the unwanted support. Permit loosening while blocked, but no further tightening until the supports are corrected. Retry/cancel must not erase damage; Retry must not bypass backing out a faulted screw.
6. Five cumulative damage strikes destroy the motherboard.

### GPU: gentle insertion and case bracket

1. Show the card from its fan-facing side, with the PCIe slot below it.
2. Lower and align the card into the slot. Excess insertion/impact speed causes physical damage; gentle seating does not.
3. Secure the card's upper case bracket with screws after seating it.
4. The metal bracket screws cannot cause overtightening damage under this game's rules.

### CPU, paste and supplied cooler

1. Use researched socket/orientation/retention references: seat the correctly oriented CPU, then close the retention arm(s). Keep the schematic coherent with the socket mechanism depicted.
2. Let the player apply thermal paste before placing the supplied cooler.
3. Preserve the user's rule: “doesnt cause penality if there is too much”; no paste means **50% CPU performance**, insufficient paste gives a loss up to that limit, and sufficient/excess paste has no penalty.
4. Place the cooler and tighten its screws gradually, alternating opposite corners to keep pressure even.
5. Fully tightening one side first must reduce cooling/overclocking headroom even if all screws eventually reach the same final tightness. Do not evaluate only the final balanced positions.
6. Poor mounting is an installation penalty, not a separate cooler product/quality stat. Retrying/reinstalling can correct paste and mounting quality.

### Shared screws, PSU and persistent damage

- Hold to tighten and show a tightness percentage. **100–150% is safe; over 150% damages susceptible parts**, including motherboard/cooler mounting. Allow backing screws out to correct mistakes.
- Metal GPU-bracket and PSU-mount screws are exempt from overtightening damage. These percentages/exemptions are intentional game simplifications, not real hardware torque advice.
- PSU minigame: align its rear mounting holes with the case and fasten the screws. Additional wiring/puzzles were not agreed requirements.
- Five cumulative strikes destroy a susceptible physical part. Commit damage immediately and authoritatively; cancellation, retry, reinstall or reopening must not erase it. Avoid duplicate application of the same strike.
- Show current strike count/condition and actual paste/mounting penalties during installation and on the bench. Offer Retry within the minigame and Reinstall for fitted parts. Correctable installation quality is distinct from irreversible physical damage.

### Existing mechanisms to reuse

- `src/workshop/assembly.gd` / `assembly.tscn`: stage flow, drawn diagrams, held screws, paste, insertion and retry.
- `src/ui/dialog_layer.gd` / `assembly_dialog.tscn`: launch guards, damage synchronization and completion.
- `src/workshop/rig_rules.gd`, `workshop_system.gd`, `src/core/game_session.gd`: compatibility, authoritative install/reinstall and persistent strikes.
- `src/workshop/overclock_rules.gd`: shared CPU paste/mounting calculations; the UI must display these results rather than duplicate the formula.
- `src/workshop/bench_view.gd` / `bench_view.tscn`: actionable prerequisites, current penalties and reinstall controls.
- `docs/asset_provenance.md`: researched mounting/socket/insertion references and origins of authored/reused artwork. Keep generated/authored asset provenance current; do not import copyrighted reference pictures as game art.

## Verification

- Manually exercise the actual runtime at representative window sizes; root inspects screenshots and interactions, not just source or a worker's completion claim.
- Confirm invalid GPU/motherboard installs never launch; compatible installs and CPU reinstall do launch.
- Exercise missing supports and extra supports under the PCB: no strike on lowering/Start Screws or at/below 50%; attempting to exceed 50% causes one strike, a red support highlight and a tightening block. Verify loosening, screw removal, lifting/correction and successful subsequent fastening without duplicate strikes. Separately leave extra supports outside the PCB footprint and verify no damage, red fault or installation block.
- Compare gentle versus fast GPU insertion and verify bracket fastening cannot add overtightening strikes.
- Exercise CPU orientation/retention, zero/partial/enough/excess paste, even versus one-corner-first mounting, and the displayed/scored penalties. Zero paste must give exactly the agreed 50% CPU-performance multiplier, with excess harmless.
- Exercise susceptible screws below/at/above the safe range, retry/cancel/reopen after damage, and destruction on the fifth strike. Confirm damage remains while paste/mounting can be repaired.
- Confirm PSU alignment/fastening is understandable and the workbench explains current penalties and available recovery without clutter. Inspect each stage's larger DO / DON'T guide, including mistake/recovery text, and confirm both motherboard views share their orientation and lettered holes.
- Run the **existing** regression suite and inspect script/shader errors. Do not create/extend automated tests or change behavioral assertions without explicit user permission. Any temporary manual preview must be isolated from live AI/real player scores and cleaned up afterward.

## Decisions and remaining work

- **Recovered/accepted:** prerequisites, researched standoffs, overlapping-extra-support damage at the 50% fastening limit, harmless non-overlapping extras, gentle GPU insertion, CPU retention/paste/even mounting, 150% screw threshold, five-strike destruction, metal-bracket exemption, bundled-only cooler, 50% maximum paste loss, visible penalties and retry/reinstall.
- **Work-in-progress checkpoint for coworker collaboration:** the stage flows, launch/host guards, persistent strikes, paste/mount modifiers, penalty readouts, retry/reinstall, shared board orientation, larger DO / DON'T guides and footprint-aware 50% resistance stop are present in source. The latest orientation/instruction/50% changes passed the existing suite apart from the four known phone expectations below, but final native end-to-end visual/interaction acceptance and balance review remain. Do not mark the minigames finished solely because these paths exist.
- Verify/tune insertion sensitivity and mounting-penalty strength within the agreed behavior. The user's five-strike limit, 150% safe threshold and paste cap are fixed requirements, not tuning options.
- The latest reported full suite has 1321 checks and four failures in obsolete **phone** size/pocket-mode expectations, with no script/shader errors. This is not a green suite or proof of completed minigame acceptance; changing those behavioral assertions still needs permission.
- This file consolidates existing decisions for review. No new minigame features or automated-test work are proposed.
