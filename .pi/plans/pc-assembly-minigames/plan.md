# PC installation minigames — recovered agreement

## Goal and constraints

Make installing a PC a clear, physically understandable sequence, available only when the required parts are actually fitted. This records the user's original installation request and subsequent corrections from the November 10 conversation; it is not a replacement design.

- Keep static controls/layout in authored Godot scenes; custom drawing is appropriate for the interactive assembly diagrams.
- Root assistant performs visual/image acceptance, as the user explicitly requested; subagents may implement or inspect source.
- Keep the workbench understandable, not overcomplicated. Show the current mistake, its actual penalty and how to correct it.
- Case tray and motherboard must use the **same orientation**. Keep larger, short control hints. Latest UX correction supersedes tutorial-like goal instructions: do not reveal the minimum screw/support threshold, constantly show errors or babysit the player with an exact fulfillment checklist. Use brief contextual failure messages and actionable repair feedback only after an actual fault.
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
3. Latest UX clarification: ordinary unfilled holes remain neutral, not red blinking errors. Only discovered harmful standoffs **under solid PCB where there is no mounting hole** are highlighted after resistance/damage. Preserve that highlight on the tray after lifting so repair feedback remains usable. Extra standoffs outside the motherboard's footprint do not collide, incur **no penalty**, and must not block installation.
4. Latest user clarification supersedes the earlier all-supports requirement: **three correctly placed standoffs with seated screws are enough to finish**, even if other required supports are missing. Missing supports remain visible as warnings and lower the displayed completion/quality, not an unconditional installation block. Latest timing clarification: when tightening would pass **50%** with an unwanted standoff overlapping solid PCB, apply one damage strike, stop the screw at the resistance point, highlight the extra support red and block further tightening. Neither lowering the board nor choosing Start Screws alone causes this damage. Reuse the drawn board footprint for the collision decision.
5. Tell the player to back out the started screw, lift the board and remove the unwanted support. Permit loosening while blocked, but no further tightening until the supports are corrected. Retry/cancel must not erase damage; Retry must not bypass backing out a faulted screw.
6. Five cumulative damage strikes destroy the motherboard.
7. New user direction: allow completing the motherboard with **three properly seated screws**. Below three, Continue is disabled; with at least three but not all required mounting holes fastened, it is enabled and neutral grey; with every required mounting hole fastened, it is green. Harmless outside-PCB supports do not add required screws. Other missing supports do not block once three correct supports have seated screws; harmful-extra faults still block completion.
8. Show screw coverage versus required screws and the player's assembly mistakes as a calm build-quality breakdown. Count each accepted damage incident once for this player's run, including destroyed parts; retry/reinstall do not erase it. Store installation coverage on the build, not the tradeable part. No additional performance/stability penalty is agreed; existing damage, paste and mounting penalties remain.
9. Keep the three-screw/support threshold internal. Blocked actions may say “Not enough screws” / “Not enough supports”, not “install at least 3”. Valid partial mounting must not be presented as an error. Normal play gives control hints, not a continuous exact-success checklist; fault messages describe the immediate repair action.

### GPU: gentle insertion and case bracket

1. Show the card from its fan-facing side, with the PCIe slot below it.
2. Lower and align the card into the slot. Excess insertion/impact speed causes physical damage; gentle seating does not.
3. Secure the card's upper case bracket with screws after seating it.
4. The metal bracket screws cannot cause overtightening damage under this game's rules.

### CPU, paste and supplied cooler

1. Use researched socket/orientation/retention references: seat the correctly oriented CPU, then close the retention arm(s). Keep the schematic coherent with the socket mechanism depicted.
   - User clarified “yes clicking the exposed pins”: clicking the exposed pins of an open socket damages the **motherboard**, not the CPU. Use its existing persistent strike count; the fifth cumulative hit destroys the motherboard and blocks CPU installation. Correct lever clicks, handling the CPU, and clicks on a seated CPU do not count. The PGA lever-only schematic has no exposed socket pins.
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
- Verify the new optional mounting rule: fewer than three correctly supported/seated screws cannot finish; three can finish with an enabled grey action despite other missing supports; every required mounting hole fastened makes the action green. Unsupported holes must not count as seated screws. Quality shows screw coverage and assembly mistakes without inventing new gameplay penalties.
- In an open LGA socket, click the exposed pin field: exactly one motherboard strike per click, CPU strikes/condition unchanged, both counters visible. Verify retry/cancel/reopen preserve board damage, the fifth cumulative motherboard hit destroys the board and blocks CPU completion, and ordinary lever/CPU interaction, closed sockets and the PGA lever-only socket remain safe. Host requests must identify an owned compatible CPU and the currently installed motherboard.
- Compare gentle versus fast GPU insertion and verify bracket fastening cannot add overtightening strikes.
- Exercise CPU orientation/retention, zero/partial/enough/excess paste, even versus one-corner-first mounting, and the displayed/scored penalties. Zero paste must give exactly the agreed 50% CPU-performance multiplier, with excess harmless.
- Exercise susceptible screws below/at/above the safe range, retry/cancel/reopen after damage, and destruction on the fifth strike. Confirm damage remains while paste/mounting can be repaired.
- Confirm PSU alignment/fastening is understandable and the workbench explains current penalties and available recovery without clutter. Inspect short control hints and contextual repair feedback: no continuous errors for valid partial mounting, no revealed numeric minimum, and the actual faulty support stays marked after lifting. Confirm both motherboard views share their orientation and lettered holes.
- Run the **existing** regression suite and inspect script/shader errors. Do not create/extend automated tests or change behavioral assertions without explicit user permission. Any temporary manual preview must be isolated from live AI/real player scores and cleaned up afterward.

## Decisions and remaining work

- **Recovered/accepted:** prerequisites, researched standoffs, overlapping-extra-support damage at the 50% fastening limit, harmless non-overlapping extras, gentle GPU insertion, CPU retention/paste/even mounting, 150% screw threshold, five-strike destruction, metal-bracket exemption, bundled-only cooler, 50% maximum paste loss, visible penalties and retry/reinstall.
- **Work-in-progress checkpoint for coworker collaboration:** stage flows, launch/host guards, persistent strikes, paste/mount modifiers, retry/reinstall, shared board orientation, DO / DON'T guides and the footprint-aware 50% resistance stop exist. New asset-backed LGA CPU/socket and two-/three-fan GPU artwork and motherboard-only pin-click damage are implemented locally. Native checks covered five cumulative pin hits (including retry/cancel/reopen and an already four-hit board), unchanged CPU condition, normal CPU seating/paste/even mounting, fast versus gentle GPU insertion, immune metal-bracket screws, ATX standoff resistance/backout/correction and harmless outside-mATX supports. Full remaining-case acceptance/balance is not complete.
- **Implemented locally:** optional completion with three supported/seated screws despite other missing supports; neutral grey partial action and green full coverage; authoritative per-build screw metadata and exactly-once run mistake count; calm workbench quality display. Native checks verified two screws disabled / three enabled with six supports absent, successful installation recorded as 3/9, unsupported holes not counting, repair/backout/lift with the bad support still marked, and 9/9 turning green. A fresh four-hit board's final pin hit removed only the board, left CPU condition/strikes unchanged and added exactly one run mistake. Latest presentation removes continuous red missing-hole markers and numeric-minimum instructions.
- **Upstream coordination:** this minigame batch is based on `c398739`, with the coworker's LuckyFold and menu changes intact. LuckyFold files match that upstream snapshot exactly; this batch makes no phone/menu source changes.
- Verify/tune insertion sensitivity and mounting-penalty strength within the agreed behavior. The user's five-strike limit, 150% safe threshold and paste cap are fixed requirements, not tuning options.
- After upstream's phone/test updates, the existing suite passes **1353 checks, 0 failures**. Root made no test or assertion changes. This is regression evidence, not proof that every minigame's remaining native acceptance/balance work is finished.
- This file records accepted mechanics and UI decisions. No new automated-test work is proposed.
