# Original Slopyard pixel-art family

`atlas.png` is original code-authored prototype pixel art created for this project with Pillow, not downloaded or extracted from Nintendo/Pokémon or another game.

Technical frame: RGBA 256×128 atlas, 32×32 cells, native 16×24-ish character silhouette, 32×32 car/prop cells, transparent unused space, nearest-neighbor filtering and no mipmaps. The world is drawn at approximately one native pixel per three display pixels; UI remains high resolution. House floors/walls, tiled roofs, street surfaces, pond, meeting signs and map are authored as integer pixel clusters in `scripts/town_view.gd` using canonical `world_rules.gd` geometry.

Family palette: warm cream/tan interiors, dusty red/blue roofs, sage grass, dark blue-charcoal outlines, muted teal clothing, pale green windows and cyan/gold car accents. Top-left light, restrained shadows; no antialiasing in source sprites.

Atlas layout:
- Row 0: four character facings, two walk frames per facing (8 cells).
- Row 1: four vehicle colors, four tree cells.
- Row 2: workbench, bed, sofa, rug; remaining cells transparent.
- Row 3: transparent reserved cells.

No third-party image license is required for this original family. The separately shipped Hack font retains its license under `assets/fonts/`.
