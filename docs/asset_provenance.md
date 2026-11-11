# Asset provenance

This records audio and visual resources authored or reused during the UI and assembly work. It does not change the licenses of pre-existing project artwork.

## Generated artwork

Three original SVG navigation icons were authored for this project; they are vector source, not image-model output. No new raster artwork, video or 3D-model asset was generated. No Apple product artwork, model, wallpaper, interface image or font is included in the game.

| File | Technical frame | Origin / rights |
| --- | --- | --- |
| `assets/ui/phone/browse.svg` | 24×24, transparent, white 2 px rounded stroke | Original project-authored magnifier; no external artwork |
| `assets/ui/phone/messages.svg` | 24×24, transparent, white 2 px rounded stroke | Original project-authored conversation bubble; not an SF Symbol |
| `assets/ui/phone/sell.svg` | 24×24, transparent, white 2 px rounded stroke | Original project-authored price tag; no external artwork |

All three are tinted by the phone theme and displayed at 18 px. Their SVG paths are the editable originals; Godot produces the imported textures.

## Authored and derived visual resources

| Resource | Origin | Use |
| --- | --- | --- |
| `resources/ui/game_theme.tres` | Serialized from this project's existing `UiKit.make_theme()` using Godot's ResourceSaver | Editor-visible shared UI theme; no external artwork |
| `resources/ui/assembly_theme.tres` | Original authored Godot theme using the existing Hack Bold font | Neutral grey enabled partial-mounting action; full mounting retains the shared green primary style |
| `src/workshop/assembly.gd` | Original drawing and interaction code composed with the repository's component textures | Case tray, schematic motherboard holes, PGA retention mechanism, PSU rear plate, supplied cooler and thermal paste; asset-backed LGA socket and fan-side GPU |
| Feature-local `.tscn` screens and component templates | Authored from the existing scripted UI | Editable layouts, cards, dialogs, buttons and labels |
| `assets/cover/slopyard-wars-cover-1260x1000.png` | Existing project title artwork, reused without modification | Main-menu centerpiece; aspect ratio preserved with nearest-neighbor sampling |
| `resources/ui/menu_theme.tres` | Original Godot theme using the project's existing Hack fonts | Main-menu teal surfaces, cream text and gold accents drawn from the cover palette |
| `src/trading/fold_face.gdshader` | Native Godot adaptation of the MIT-licensed iPhone Duo screen shader | Projected fold-face sampling, blur and darkening; see [third-party notices](third_party_notices.md) |
| `src/trading/fault_hue.gdshader` | Original shader applied to the existing fault PNG | Colour shifts and slight horizontal-band thickening in the intentional damaged display; source PNG and vertical column unchanged, no new image asset |
| `src/trading/oled_cast.gdshader` | Original native shader on the authored rounded display overlay | Brief white signal-loss flash with sparse broken coloured scanlines at the first snap per match; removed when the normal image and existing fault lines return, with no persistent colour wash or new image asset |
| `resources/ui/phone_theme.tres` | Original authored Godot theme using installed Noto Sans / DejaVu Sans | Feature-local dark app surfaces, blue controls and readable typography; no new font files |
| `src/trading/phone.gd` and authored chassis nodes in `phone.tscn` | Original projected solid geometry informed by the fold study's dimensions/hinge transform | Rounded sidewalls, beveled rails, physical hinge clearance; no imported model |
| Closed/open styles in `src/trading/luckyfold_shell.tscn` | Original procedural casing shapes | Straight closed hinge edge, rounded outside corners; replaces the legacy nine-patch rendering |

The assembly drawings are educational game schematics, not dimensionally accurate fabrication templates. Coolers are minigame props supplied with the CPU, not marketplace products. Percentage-based screw tightness, the 150% threshold, five-strike destruction and metal-bracket immunity are game rules, not real-world torque guidance.

## Storage side-elevation family

Authored for this redesign as original SVG source and Godot drawing code; no image-model output or downloaded photo pixels. The assets use the bench's navy, cyan and grey-metal palette, transparent 360×112 canvases, and two separated side holes at (64,61) and (296,61). Godot imports SVG alpha natively; explicit preloads in `art_library.gd` make the dependencies exportable. No mipmaps or opaque backdrop are needed. Approval: awaiting the root's in-game visual review.

| File / resource | Original design and use | Rights / restrictions |
| --- | --- | --- |
| `assets/computer_parts/storage/hdd_side.svg` | Long, shallow 147:26 sidewall silhouette, silver lid seam, cast ribs, lower PCB lip and rear connector; not a top-view label/platter image | Original project-authored vector; no third-party artwork or attribution requirement |
| `assets/computer_parts/storage/ssd_caddy_side.svg` | Thin 2.5-inch SATA SSD on an educational bay caddy, visibly distinct from the full-height HDD | Original project-authored vector; same terms |
| `_draw_m2_mount()` / `_draw_m2_drive()` in `src/workshop/assembly.gd` | Original top-view M.2 PCB, keyed gold edge, motherboard connector and single end standoff/screw; Bolt never uses a bay carrier | Original project-authored drawing code; same terms |
| `_draw_storage_bay()` / `_draw_storage_flange()` in `src/workshop/assembly.gd` | Open cage uprights, adjacent empty bay, folded rails, punched slots, raised mounting ears. Artwork, picking, placement target and screw centres share the same canvas/geometry | Original project-authored drawing code; same terms |

Physical references (reference-only; copyrighted photos/PDF figures are **not shipped**, traced or embedded):

- [ASUS HDD/SSD installation FAQ 1049212](https://www.asus.com/us/support/faq/1049212/): actual drive/tray photographs show stamped tray lips and two widely separated side screws. ASUS specifies four HDD screws total, two per side. Temporary research crops `/tmp/slopyard-hdd-bay-reference.png` and `/tmp/slopyard-hdd-side-screws-reference.png` were visually inspected; they remain outside the repository.
- [Seagate BarraCuda product manual 100804187f](https://www.seagate.com/www-content/product-content/barracuda-fam/barracuda-new/en-us/docs/100804187f.pdf): mechanical reference for the approximately 147×101.6×26 mm 3.5-inch drive envelope. The side drawing reflects length/thickness, not a fabrication template.

HDD/SATA interaction is schematic: slide onto the runners, fasten two near-side screws, then automatically expose the opposite side for the remaining two. The Flashy SATA SSD retains its bay caddy. Bolt NVMe instead inserts into a motherboard M.2 edge connector, lowers onto an end standoff and fastens with one screw. Its 80:22 PCB close-up is a schematic, not a catalog claim about exact module dimensions. Universal game storage compatibility, inventory/catalog art and hardware specifications are unchanged.

## External font assets

`assets/fonts/pixel_operator/` contains the unmodified **Pixel Operator** family by Jayvee Enaguas (HarvettFox96), sourced from the [author's dafont distribution](https://www.dafont.com/pixel-operator.font) ([original ZIP](https://dl.dafont.com/dl/?f=pixel_operator)). The archive's full **CC0 1.0 Universal** license is preserved alongside the fonts as `LICENSE.txt`; embedded font metadata also identifies CC0.

- `PixelOperator8.ttf` / `PixelOperator8-Bold.ttf`: native 8px cut for labels inside the low-resolution world viewport.
- `PixelOperator.ttf` / `PixelOperator-Bold.ttf`: native 16px cut for the screen-resolution town overview.
- Import with no antialiasing, hinting or subpixel positioning, 1× oversampling and whole-pixel advances. Draw at the native sizes and integer positions. Menus, workbench and phone fonts are unchanged.

These are sourced font assets, not generated artwork or modified outlines.

## Audio

`assets/audio/` contains 24 playback WAV assets at 44.1 kHz / 16-bit: 22 original synthesized assets and two edited CC0 hinge recordings. The generated assets use `scripts/generate_audio.cjs` and Node's standard library, with no external samples, melodies or synthesis libraries. Their source/provenance note is [`assets/audio/licenses/GENERATED_AUDIO.txt`](../assets/audio/licenses/GENERATED_AUDIO.txt); `assets/audio/manifest.json` lists every playback asset, duration, channels, levels and recorded-source metadata. Regenerating synthesized audio preserves the recorded hinges.

**Slopyard Afterhours** is an original 16-bar, 80 BPM downtempo arrangement with electric-piano-style FM keys, soft sine pads, rounded bass, brushed percussion and a sparse melody. Its stereo delay tails wrap across the 48-second loop boundary. Generated effects use waveform, noise-burst, chirp, envelope and resonator synthesis. The fracture transient is triggered by the visual failure callback. Godot's `.wav.import` sidecars preserve resource IDs and import settings and belong in version control alongside the source WAVs.

`hinge_open.wav` and `hinge_close.wav` use separate excerpts of **creaky door hinge.wav** by **chonkdonk**, [Freesound sound 619819](https://freesound.org/people/chonkdonk/sounds/619819/), published as **CC0 1.0**. The publicly available HQ MP3 preview is preserved in `assets/audio/sources/chonkdonk_619819_hinge.mp3`. Mono conversion, gentle filtering, resampling, fades and level adjustment are reproducible with `scripts/prepare_hinges.gd`. Each output lasts 1.15 seconds, with the opening creak delayed to match the phone's lateral shift. The full CC0 legal text and individual source/license records are in `assets/audio/licenses/CC0-1.0.txt`, `hinge_open.LICENSE.txt` and `hinge_close.LICENSE.txt`.

## User-supplied meeting NPCs

`assets/npcs/npc_cap.png`, `npc_bob.png` and `npc_glasses.png` are the user's supplied artwork from `slopyard_npc_32x32.zip`. Only the three regular PNG entries were extracted after filename/type/size and decoded-image inspection. All are transparent 32×32 RGBA images, preserved byte-for-byte (466, 493 and 494 bytes respectively); `assets/npcs/manifest.json` records SHA-256 hashes. No image generation, recolouring or new licensing claim is involved; ownership/terms remain those of the supplied artwork.

Explicit `ArtLibrary` preloads select appearance by stable character identity, not listing order. Town rendering uses nearest-neighbour sampling and the source's y=29 ground anchor, leaving player art and ground-depth sorting unchanged. `Market.meeting_position(raw_booking)` chooses a clear nearby ground position away from the canonical sign, with geometry-aware fallback candidates; active meeting copies and physical handoffs share that position without modifying booking labels or canonical trade options.

## Reused visual assets

- `assets/computer_parts/`: existing component textures, reused for inventory and assembly illustrations.
- `assets/player/{down,up,left,right}/`: existing 32×32 directional player sprites, integrated unchanged in place of the legacy atlas player. Each direction has an idle frame; vertical walks use two frames and horizontal walks use all four. A shared foot anchor and nearest-neighbour drawing preserve world alignment. No new character artwork was generated.
- `assets/interior/`, `assets/tiles/` and other existing world art: reused; desk sizing and floor tiling are rendering changes, not newly generated artwork.
- `assets/ui/luckyfold/display_fault.png`: existing artwork reused at runtime; its damaged-screen geometry is intentional. `device_frame.png` is preserved as a legacy/reference file, not used by the new procedural casing.
- `assets/fonts/Hack-Regular.ttf` and `Hack-Bold.ttf`: existing UI fonts, unchanged. World/map labels use the dedicated pixel-font assets above rather than shrinking these fonts.

### Assembly close-ups from the coworker's asset branch

These PNGs were supplied in the repository's `assets` branch and merged in `cb0d31c`; they were not generated or redrawn during this integration. Their existing ownership/terms are unchanged.

| Files | Native size | Assembly use |
| --- | --- | --- |
| `assets/computer_parts/cpus/close_up/cpu_closeup.png` | 128×128 | Rotatable CPU; its visible package and gold-corner cue share the placement/picking geometry |
| `assets/computer_parts/cpus/close_up/socket_open.png`, `socket_closed.png`, `socket_closed_with_cpu.png` | 192×192 each | Open, empty closed and CPU-retained LGA states; lever hit targets follow the artwork. OX4 keeps its distinct PGA lever-only schematic |
| `assets/computer_parts/graphics_cards/gpu_fan_side_2_fans.png` | 128×72 | Short fan-side GPU variant |
| `assets/computer_parts/graphics_cards/gpu_fan_side_3_fans.png` | 160×72 | Long fan-side GPU variant |

GPU variants use the existing name-hash visual-variant convention, not invented fan-count performance stats. Both mount to the same case-bracket edge and share the same gold-connector footprint; the PCIe socket/latch follow those pixels. Rendered card dimensions also determine picking and placement outlines. Textures use nearest-neighbour filtering with no generated mipmaps. No source PNG was modified.

## External references — not shipped as artwork

These references guided the original procedural diagrams and physical fold projection. Reference images and models were not imported into the game.

- [ATX Specification 2.2](https://xdevs.com/doc/_PC_HW/Form_factors/atx2_2.pdf), Figure 2, page 10: ATX and microATX mounting-hole topology. ATX uses A/C/F/G/H/J/K/L/M; microATX uses B/C/F/H/J/L/M/R/S. Figure 3 provides an example physical layout.
- [microATX Motherboard Interface Specification 1.2](https://xdevs.com/doc/_PC_HW/Form_factors/matxspe1.2.pdf): mounting-hole and removable-standoff guidance.
- [Intel LGA1700 installation guidance](https://www.intel.com/content/www/us/en/support/articles/000088402/processors.html) and the [Intel boxed processor installation illustrations](https://edshop.edsystem.eu/fileshare/products/specification/int/instructions-lga-1700_with-integrated-graphics_with-fan-heat-sink%28537770%29.pdf): CPU orientation, retention mechanism and cooler assembly.
- [ASUS graphics-card installation guidance](https://www.asus.com/us/support/faq/1047391/): downward PCIe insertion, latch and case-bracket fastening.
- [iPhone Duo fold study](https://github.com/chuspeeism/iphone-duo): cover-to-inner-display transition reference. Its application code is MIT-licensed; Apple reference assets are separately owned and excluded from that license. Those assets are not imported into this game.

Downloaded PDFs, cropped research diagrams, browser screenshots and temporary manual-preview captures are working references, not shipped assets. Runtime phone snapshots, if used for a transition, are transient textures rather than saved game artwork.
