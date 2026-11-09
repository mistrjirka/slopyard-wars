# Pixel-art integration

The supplied asset pack is connected through `src/ui/art_library.gd`, using explicit preloads and nearest-neighbor filtering. Source PNGs are unchanged.

- `buildings/`, `tiles/`, and `vegetation/` draw the town in `src/world/world_backdrop.gd`.
- `interior/` furnishes the home. Wooden workbench/desk variants switch to metal when a case is installed.
- `decorations/lucky/` decorates the home and Lucky Square.
- `world_activities/` contains five labeled placeholder PNGs already rendered at the town's interactive stops. Overwrite them in place for finished art; see [the artist brief](../../docs/art_brief.md). The existing Lucky statue is layered over the shrine base.
- Front, rear and side car images show facing in the world; the top image marks the car on the map.
- Small and detailed computer-part variants appear in listings, inventory, menu art and assembly. Storage artwork distinguishes HDDs from solid-state drives.

Static scenery is cached separately from dynamic actors. Collision shapes still come from `src/world/world_rules.gd`. Unneeded source variants, such as the corner road tile, remain available in the art registry for future map edits.

## Original character atlas

`atlas.png` is original code-authored prototype pixel art created for this project with Pillow, not downloaded or extracted from Nintendo/Pokémon or another game.

Technical frame: RGBA 256×128 atlas, 32×32 cells, native 16×24-ish character silhouette, transparent unused space, nearest-neighbor filtering and no mipmaps. Only the character row is used by the active renderer. The world is drawn at approximately one native pixel per three display pixels; UI remains high resolution. Pond, meeting signs and structural accents remain code-drawn alongside the supplied textures.

Family palette: warm cream/tan interiors, dusty red/blue roofs, sage grass, dark blue-charcoal outlines, muted teal clothing, pale green windows and cyan/gold car accents. Top-left light, restrained shadows; no antialiasing in source sprites.

Atlas layout:
- Row 0: four character facings, two walk frames per facing (8 cells).
- Row 1: four vehicle colors, four tree cells.
- Row 2: workbench, bed, sofa, rug; remaining cells transparent.
- Row 3: transparent reserved cells.

No third-party image license is required for this original family. The separately shipped Hack font retains its license under `assets/fonts/`.
