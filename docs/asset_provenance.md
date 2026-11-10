# Visual asset provenance

This records assets and visual resources authored or reused during the UI and assembly work. It does not change the licenses of pre-existing project artwork.

## Generated artwork

Three original SVG navigation icons were authored for this project; they are vector source, not image-model output. No new raster artwork, audio, video or 3D-model asset was generated. No Apple product artwork, model, wallpaper, interface image or font is included in the game.

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
| `src/workshop/assembly.gd` | Original procedural drawing and interaction code | Case tray, schematic motherboard holes, socket/retention mechanism, GPU fan-side view, PSU rear plate, supplied cooler and thermal paste |
| Feature-local `.tscn` screens and component templates | Authored from the existing scripted UI | Editable layouts, cards, dialogs, buttons and labels |
| `src/ui/menu_parts_art.gd` | Existing project part textures composed by original drawing code | Main-menu illustration |
| `src/trading/fold_face.gdshader` | Native Godot adaptation of the MIT-licensed iPhone Duo screen shader | Projected fold-face sampling, blur and darkening; see [third-party notices](third_party_notices.md) |
| `src/trading/fault_hue.gdshader` | Original shader applied to the existing fault PNG | Colour shifts and slight horizontal-band thickening in the intentional damaged display; source PNG and vertical column unchanged, no new image asset |
| `resources/ui/phone_theme.tres` | Original authored Godot theme using installed Noto Sans / DejaVu Sans | Feature-local dark app surfaces, blue controls and readable typography; no new font files |
| `src/trading/phone.gd` and authored chassis nodes in `phone.tscn` | Original projected solid geometry informed by the fold study's dimensions/hinge transform | Rounded sidewalls, beveled rails, physical hinge clearance; no imported model |
| Closed/open styles in `src/trading/luckyfold_shell.tscn` | Original procedural casing shapes | Straight closed hinge edge, rounded outside corners; replaces the legacy nine-patch rendering |

The assembly drawings are educational game schematics, not dimensionally accurate fabrication templates. Coolers are minigame props supplied with the CPU, not marketplace products. Percentage-based screw tightness, the 150% threshold, five-strike destruction and metal-bracket immunity are game rules, not real-world torque guidance.

## External font assets

`assets/fonts/pixel_operator/` contains the unmodified **Pixel Operator** family by Jayvee Enaguas (HarvettFox96), sourced from the [author's dafont distribution](https://www.dafont.com/pixel-operator.font) ([original ZIP](https://dl.dafont.com/dl/?f=pixel_operator)). The archive's full **CC0 1.0 Universal** license is preserved alongside the fonts as `LICENSE.txt`; embedded font metadata also identifies CC0.

- `PixelOperator8.ttf` / `PixelOperator8-Bold.ttf`: native 8px cut for labels inside the low-resolution world viewport.
- `PixelOperator.ttf` / `PixelOperator-Bold.ttf`: native 16px cut for the screen-resolution town overview.
- Import with no antialiasing, hinting or subpixel positioning, 1× oversampling and whole-pixel advances. Draw at the native sizes and integer positions. Menus, workbench and phone fonts are unchanged.

These are sourced font assets, not generated artwork or modified outlines.

## Reused assets

- `assets/computer_parts/`: existing component textures, reused for inventory and assembly illustrations.
- `assets/interior/`, `assets/tiles/` and other existing world art: reused; desk sizing and floor tiling are rendering changes, not newly generated artwork.
- `assets/ui/luckyfold/display_fault.png`: existing artwork reused at runtime; its damaged-screen geometry is intentional. `device_frame.png` is preserved as a legacy/reference file, not used by the new procedural casing.
- `assets/fonts/Hack-Regular.ttf` and `Hack-Bold.ttf`: existing UI fonts, unchanged. World/map labels use the dedicated pixel-font assets above rather than shrinking these fonts.

## External references — not shipped as artwork

These references guided the original procedural diagrams and physical fold projection. Reference images and models were not imported into the game.

- [ATX Specification 2.2](https://xdevs.com/doc/_PC_HW/Form_factors/atx2_2.pdf), Figure 2, page 10: ATX and microATX mounting-hole topology. ATX uses A/C/F/G/H/J/K/L/M; microATX uses B/C/F/H/J/L/M/R/S. Figure 3 provides an example physical layout.
- [microATX Motherboard Interface Specification 1.2](https://xdevs.com/doc/_PC_HW/Form_factors/matxspe1.2.pdf): mounting-hole and removable-standoff guidance.
- [Intel LGA1700 installation guidance](https://www.intel.com/content/www/us/en/support/articles/000088402/processors.html) and the [Intel boxed processor installation illustrations](https://edshop.edsystem.eu/fileshare/products/specification/int/instructions-lga-1700_with-integrated-graphics_with-fan-heat-sink%28537770%29.pdf): CPU orientation, retention mechanism and cooler assembly.
- [ASUS graphics-card installation guidance](https://www.asus.com/us/support/faq/1047391/): downward PCIe insertion, latch and case-bracket fastening.
- [iPhone Duo fold study](https://github.com/chuspeeism/iphone-duo): cover-to-inner-display transition reference. Its application code is MIT-licensed; Apple reference assets are separately owned and excluded from that license. Those assets are not imported into this game.

Downloaded PDFs, cropped research diagrams, browser screenshots and temporary manual-preview captures are working references, not shipped assets. Runtime phone snapshots, if used for a transition, are transient textures rather than saved game artwork.
