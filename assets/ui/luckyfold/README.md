# LuckyFold Duo artist handoff

## Casing and fold

The current casing is procedural, not a stretched PNG. `src/trading/luckyfold_shell.tscn` contains the closed/open StyleBoxFlat shapes: a straight left hinge edge while closed and rounded outside corners. `src/trading/phone.tscn` contains the authored chassis/hinge polygons and captured screen faces. `phone.gd` projects solid sidewalls and beveled rims, with the stationary camera half separated from the moving cover.

Both halves use one responsive scale. The open aspect follows the reference's 2670×1878 inner screen. The closed phone rests centered, shifts right, then opens to the left; closing reverses the path. Keep the live and captured endpoint silhouettes consistent when changing the casing. The old 128×128 `device_frame.png` is retained as a legacy/reference asset, but is no longer the runtime casing.

## Display-fault PNG

`display_fault.png` is a **1024×768 RGBA** transparent overlay scaled to the inner display. Its opaque pale/lime/purple horizontal rows extend from the hinge toward the right at y≈650, with a narrow vertical column continuing downward. Preserve transparent pixels elsewhere.

This represents **failed pixel rows/columns**, not a spiderweb glass crack. The original placeholder follows the geometry visible in [iFixit's reference photo](https://www.ifixit.com/News/119895/iphone-duo-teardown), not copied photo pixels. Keep the fault within x≥510, y≥648; preserve the horizontal band's bottom at y=656 and the vertical column within x=510..516. These are the source-art bounds. At runtime the shader expands only the horizontal strip from 8 to 12 source pixels (ending at y=660); `DISPLAY_FAULT_BAND_BOTTOM` supplies the matching layout/sampling bound so typing and Send text remain below it.

The shader gently changes lit colours over time and briefly on presses. Dark/transparent pixels and the rest of the app remain unchanged. Do not bake flicker or animation frames into the PNG.

## App and branding

The engine renders screen backgrounds, controls and **LuckyFold Duo** branding. Do not paint text or button artwork into the casing. App styling lives in `resources/ui/phone_theme.tres`; the three original 24×24 SVG tab icons live under `assets/ui/phone/`.

In conversations, the message box's upper edge sits behind the horizontal stripe; input and Send text sit below it and to the right of the vertical column. Quick replies stay above it. The bottom navigation remains clear and stays visible inside conversations. Pocket and mood-lighting captions are no longer displayed. Preserve these interaction areas when changing artwork.

See `docs/asset_provenance.md` and `docs/third_party_notices.md` for origins and the reference fold-study license. No Apple model, wallpaper, interface image or font is included.
