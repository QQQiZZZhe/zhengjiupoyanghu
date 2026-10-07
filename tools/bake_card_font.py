"""Bake native 16 px glyph masks for direct pixel composition in Godot."""
from pathlib import Path
import json
from PIL import Image, ImageFont

root = Path(__file__).resolve().parents[1]
font = ImageFont.truetype(str(root / "fonts/RenOuFangSong-16.ttf"), 16)
text = "测试卡知识卡未收集？0123456789"
for path in (root / "scripts").glob("*.gd"):
    text += path.read_text(encoding="utf-8")
characters = sorted({c for c in text if c.isprintable()})
atlas = Image.new("RGBA", (1024, ((len(characters) + 63) // 64) * 16))
mapping = {}
for index, character in enumerate(characters):
    mask = font.getmask(character, mode="L")
    assert set(bytes(mask)) <= {0, 255}, repr(character)
    x, y = (index % 64) * 16, (index // 64) * 16
    width = int(font.getlength(character))
    assert 0 < width <= 16 and mask.size[1] <= 16
    for row in range(mask.size[1]):
        for col in range(mask.size[0]):
            if mask[row * mask.size[0] + col]:
                atlas.putpixel((x + col, y + row), (255, 255, 255, 255))
    mapping[character] = [x, y, width]
atlas.save(root / "assets/art/card-font-glyphs.png")
(root / "assets/art/card-font-glyphs.json").write_text(json.dumps(mapping, ensure_ascii=False), encoding="utf-8")
print(f"Baked {len(mapping)} native pixel glyphs without antialiasing.")
