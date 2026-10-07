# Rigid Card Gyro

Every card face, selection frame and knowledge-card foil rotates as one planar
surface around the same canvas-space center. The original pointer angle limits,
frame-rate-independent damping, hover lift and return motion are preserved.

`scripts/card_rigid_projection.gdshaderinc` contains the shared rigid rotation and
perspective projection. `scripts/card_rigid.gdshader` samples the card image with
perspective-correct UV coordinates: interpolate UV/depth and 1/depth, then divide
in the fragment shader. This removes texture deformation across the two canvas
triangles. The foil shader includes the same projection and uses the same corrected
coordinates for its foil pattern and edge mask.

`_bind_card_gyro()` propagates the material through the card subtree. Hand, deck,
dispatch and enlarged details all use the same shader. Bitmap names, numeral fees
and their one-pixel shadows remain part of the original pixel card texture; no
viewport rasterization or additional physics bodies are needed.

## Verification

Create an isolated project with `tests/prepare_visual_test.py card_gyro`, import
it with Godot, then run `tests/card_gyro.tscn` with a graphical renderer. The test
samples a projected checker pattern against an independently inverted planar
camera projection. At a 0.32-radian tilt on both axes, all 1665 interior samples
match; the former affine shader disagrees at 1434 samples of the same pattern.
The old teammate shader is retained as a regression fixture.

The remaining checks cover hand selection, locked prices, material inheritance,
hover and return motion, deck and dispatch grids, action and knowledge details,
and small-window framing. Set `POYANG_SCREENSHOT_DIR` to an existing output
directory to capture the real viewport. `tests/pixel_cards.tscn` separately
checks all card names, tiers, original paper pixels and exact RGB(150,150,150)
shadows in the source bitmap.
