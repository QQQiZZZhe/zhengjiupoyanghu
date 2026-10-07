"""Create an isolated Godot test copy without touching the player's saved game."""
from pathlib import Path
import shutil
import tempfile
import sys
source = Path(__file__).resolve().parents[1]
target = Path(tempfile.mkdtemp(prefix="poyang-visual-test-"))
for name in ("scripts", "scenes", "assets", "fonts", "tests", "addons", "tools"):
    shutil.copytree(source / name, target / name)
shutil.copy2(source / "icon.svg", target / "icon.svg")
config = (source / "project.godot").read_text(encoding="utf-8")
config = config.replace('config/name="保卫鄱阳湖"', 'config/name="Poyang Visual Test"\nconfig/use_custom_user_dir=true\nconfig/custom_user_dir_name="' + target.name + '"')
entry = sys.argv[1] if len(sys.argv) > 1 else "visual_smoke"
if entry not in ("visual_smoke", "sandpan_actions", "talent_tree", "knowledge_cards", "card_gyro", "achievement_cards", "map_render", "zoom_performance", "sandpan_view", "pixel_cards", "seasonal_water", "metric_effects", "seasonal_scenery", "seasonal_animation", "tree_seasons", "situation_hud"):
    raise ValueError("Unknown visual test scene")
config = config.replace('run/main_scene="res://scenes/main.tscn"', f'run/main_scene="res://tests/{entry}.tscn"')
(target / "project.godot").write_text(config, encoding="utf-8")
print(target)
