"""Write the supplied 16 px font into the original card pixels, without smoothing."""
from pathlib import Path
from PIL import Image, ImageFont

ROOT = Path(__file__).resolve().parents[1]
ART = ROOT / "assets" / "art"
font = ImageFont.truetype(str(ROOT / "fonts" / "RenOuFangSong-16.ttf"), 16)
ink = (0, 0, 0, 255)
shadow = (150, 150, 150, 255)
glyphs = Image.new("RGBA", (80, 16), (0, 0, 0, 0))
for index, character in enumerate("0123456789"):
    width = 8
    mask = font.getmask(character, mode="L")
    assert set(bytes(mask)) <= {0, 255}, "Font must rasterize to crisp source pixels"
    assert mask.size == (width, 16)
    for y in range(16):
        for x in range(width):
            if mask[y * width + x]:
                glyphs.putpixel((index * 8 + x, y), ink)
glyphs.save(ART / "artist-cost-glyphs.png")

original = Image.open(ART / "artist-test-card-blank.png").convert("RGBA")
result = original.copy()
content = "600"  # Arabic digits, with no currency suffix.
mask = font.getmask(content, mode="L")
width, height = mask.size
left, top = 18 + (60 - width) // 2, 100
written = set()
for offset, color in [(1, shadow), (0, ink)]:
    for y in range(height):
        for x in range(width):
            if mask[y * width + x]:
                point = (left + x + offset, top + y + offset)
                result.putpixel(point, color)
                written.add(point)
for y in range(original.height):
    for x in range(original.width):
        if (x, y) not in written:
            assert result.getpixel((x, y)) == original.getpixel((x, y))
result.save(ART / "artist-test-card.png")
result.resize((576, 864), Image.Resampling.NEAREST).save(ART / "artist-test-card-6x.png")
print(f"Wrote {len(written)} font pixels; all other source pixels unchanged.")
