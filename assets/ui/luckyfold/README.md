# LuckyFold Duo artist handoff

There are **two runtime PNGs**, already used by the device. Overwrite either file with the same dimensions and filename; Godot reimports it without code or scene edits. No separate open/closed casing, brand-text texture, button sprites or animation frames are required.

| File | Canvas | Contract |
| --- | --- | --- |
| `device_frame.png` | 128×128 RGBA | Shared nine-patch casing. The outer 40 pixels on each side preserve the corners; the middle stretches to fit both folded and unfolded modes. Keep transparency outside the rounded silhouette. Avoid lettering or decorative details in the stretchable center. |
| `display_fault.png` | 1024×768 RGBA | Transparent overlay scaled to the entire inner display. The current stand-in is an opaque white/lime horizontal band from the center hinge to the right edge at y≈650, with a thin vertical column continuing to the bottom. Preserve transparent pixels everywhere else. |

The display fault should resemble **failed pixel rows/columns**, with a solid illuminated stripe. It is not a spiderweb crack in the glass. The lower-right placement follows the requested reference; the current original placeholder is based on the geometry visible in [iFixit's reference photo](https://www.ifixit.com/News/119895/iphone-duo-teardown), rather than copied photo pixels. Keep the fault within x≥510, y≥648 to preserve the interaction area above it. No flicker is required.

The engine draws the screen backgrounds, faint hinge, controls and **LuckyFold Duo** name. The name is centered in the free space below the closed cover screen, so it must not be painted into the casing. The unfolded footer places the P / Esc hint on the left and the mood-lighting caption on the right, at the same height below the app content. The failed pixels occupy the lower-right.

In unfolded conversations, the message box's upper edge sits behind the horizontal stripe, with input and Send text below it. Quick replies sit above the stripe. Preserve the horizontal band's bottom at y=656 and the vertical column within x=510..516 so the typing area to its right stays readable. The footer positions are unchanged.

These PNGs are intentionally simple stand-ins. The casing can gain wear, metal and edge detail; the fault can gain subtle colored edge pixels while retaining its clean solid line. Do not rerun the temporary placeholder generator after replacing them with finished artwork.
