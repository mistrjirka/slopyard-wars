# Ready-to-replace world artwork

All five requested art files already exist in `assets/world_activities/` as colored, labeled **128×128 RGBA PNGs**, and are connected to the game. Open and repaint the actual PNG, then save over it with the same filename. Godot reimports it automatically; no code, resource or scene edits are needed. Preserve the canvas size and PNG format. Source project files can live beside them, but the PNG is the runtime asset.

| File | Draw this | In-world canvas |
| --- | --- | --- |
| [lucky_shrine.png](../assets/world_activities/lucky_shrine.png) | A tiny silicon altar with fan-shaped candles, offerings of RAM and a coin tray. Leave the center available for the existing Lucky statue overlay. | 64×64 |
| [salvage_bin.png](../assets/world_activities/salvage_bin.png) | A battered bin full of cables and abandoned boards; a crooked “TESTED WORKING” sticker is welcome. | 40×40 |
| [dust_clinic.png](../assets/world_activities/dust_clinic.png) | A compressed-air cleaning stand with brush, mask and a ridiculously large pile of expelled dust. | 56×56 |
| [paste_club.png](../assets/world_activities/paste_club.png) | A small thermal-paste club stall: syringe, heatsink display, fan and a ceremonial pea-size blob. | 64×64 |
| [advice_board.png](../assets/world_activities/advice_board.png) | A community noticeboard / miniature confessional with benchmark slips and a tangled cable offering. | 48×48 |

Replace the colored background with transparency around the finished object. Remove the placeholder lettering; the game draws the location label separately. Match the existing town's slightly elevated perspective, muted palette, dark outlines and top-left light. Nearest filtering is already configured. Favor recognizable silhouettes over tiny baked-in text.

Each canvas is centered horizontally on its encounter position, with its bottom four world pixels below that point. Keep the visible base near the canvas bottom. Artwork does not change collision or interaction range.

The shrine layers `assets/decorations/lucky/statue_lucky.png` over the base at 32×48 world pixels. On the 128×128 shrine canvas, the overlay occupies x=32–96, y=32–128. Draw the platform and offerings around that region; do not paint a second Lucky into the base. The existing statue can also be revised in place if desired.

These static sprites are the complete art handoff for the implemented stops. No animation frames or additional UI art are required for them to work. Do not rerun the temporary placeholder generator over finished artwork.

## LuckyFold Duo

Two additional, already connected PNGs live in [`assets/ui/luckyfold/`](../assets/ui/luckyfold/): `device_frame.png` (shared 128×128 nine-patch casing) and `display_fault.png` (1024×768 transparent lower-right pixel-failure overlay). See the [phone artist handoff](../assets/ui/luckyfold/README.md) for exact bounds. The closed-screen name is live text; the artist does not need to create lettering or separate open/closed skins.
