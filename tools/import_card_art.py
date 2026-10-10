"""Install the artist's Card templates without resampling the finished faces."""
from pathlib import Path
import argparse
import shutil
import zipfile
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "tools/art_sources/card-20261010"
CATEGORIES = {
    "地理": "geography", "植物": "plants", "鸟类": "birds",
    "水生动物": "aquatic", "外来物种": "invasive", "机制": "mechanisms",
    "保护行动": "conservation", "案例": "cases", "管理策略": "management",
}
SUITS = {"生态": "ecology", "社会": "social", "管理": "manage"}


def copy_face(source: Path, destination: Path) -> None:
    shutil.copyfile(source, destination)
    settings = destination.with_suffix(destination.suffix + ".import")
    if settings.exists():
        # Nearest-filtered pixel art should retain the supplied RGBA pixels,
        # including faint border pixels that Godot's alpha repair would recolor.
        text = settings.read_text(encoding="utf-8")
        settings.write_text(text.replace("process/fix_alpha_border=true", "process/fix_alpha_border=false"), encoding="utf-8")


def install(archive: Path | None = None) -> None:
    if archive:
        with zipfile.ZipFile(archive) as bundle:
            for entry in bundle.infolist():
                if entry.is_dir():
                    continue
                relative = Path(entry.filename).relative_to("Card")
                target = (SOURCE / relative).resolve()
                if not target.is_relative_to(SOURCE.resolve()):
                    raise ValueError(entry.filename)
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_bytes(bundle.read(entry))

    knowledge = ROOT / "assets/art/knowledge"
    for category, slug in CATEGORIES.items():
        copy_face(SOURCE / f"kd-done/知识卡/kardz-{category}.png", knowledge / f"{slug}.png")
    for source, dest in [("anno", "unknown"), ("dxh", "easter-egg")]:
        copy_face(SOURCE / f"kd-done/知识卡/kardz-{source}.png", knowledge / f"{dest}.png")

    for category, slug in SUITS.items():
        source = SOURCE / f"kd-done/手牌/kd_{category}.png"
        shutil.copyfile(source, ROOT / f"assets/art/card-suits/{slug}.png")
        # No banknote or paperclip on dispatch cards. Retain the supplied blank
        # frame, then restore the matching hand template's category and icon.
        blank = Image.open(SOURCE / "kd-空白备份/empt.png").convert("RGBA")
        blank = blank.resize((400, 600), Image.Resampling.NEAREST)
        hand = Image.open(source).convert("RGBA")
        blank.paste(hand.crop((0, 0, 400, 140)), (0, 0))
        blank.save(ROOT / f"assets/art/dispatch/{slug}.png")
    print("Installed 3 hand faces, 9 knowledge faces, unknown/easter egg, and 3 dispatch bases.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("archive", type=Path, nargs="?")
    install(parser.parse_args().archive)
