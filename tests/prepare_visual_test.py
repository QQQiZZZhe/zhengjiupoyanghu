"""Create an isolated Godot test copy without touching the player's saved game."""
from pathlib import Path
import shutil
import tempfile
import sys
import re
source = Path(__file__).resolve().parents[1]
if len(sys.argv) > 2:
    target = Path(sys.argv[2]).resolve()
    target.mkdir(parents=True, exist_ok=False)
else:
    target = Path(tempfile.mkdtemp(prefix="poyang-visual-test-"))
for name in ("scripts", "scenes", "assets", "fonts", "tests", "addons", "tools"):
    shutil.copytree(source / name, target / name)
shutil.copy2(source / "icon.svg", target / "icon.svg")
config = (source / "project.godot").read_text(encoding="utf-8")
config = config.replace('config/name="鄱阳归翎-生态修复手记"', 'config/name="Poyang Visual Test"\nconfig/use_custom_user_dir=true\nconfig/custom_user_dir_name="' + target.name + '"')
config = re.sub(r'^config/(?:use_custom_user_dir|custom_user_dir_name)\.windows=.*\n', "", config, flags=re.MULTILINE)
entry = sys.argv[1] if len(sys.argv) > 1 else "visual_smoke"
if entry not in ("staged_board", "impact_feedback", "card_tooltip", "runtime_performance", "animation_performance", "motion_web", "motion_lifecycle", "rapid_settlement", "dispatch_reorder", "art_revision", "visual_smoke", "sandpan_actions", "talent_tree", "knowledge_cards", "card_gyro", "achievement_cards", "map_render", "zoom_performance", "sandpan_view", "pixel_cards", "seasonal_water", "metric_effects", "seasonal_scenery", "seasonal_animation", "tree_seasons", "situation_hud", "turn_budget", "card_burn", "card_deal", "crisis_history", "wildlife_behavior", "bird_migration", "drainage_cards"):
    raise ValueError("Unknown visual test scene")
config = config.replace('run/main_scene="res://scenes/main.tscn"', f'run/main_scene="res://tests/{entry}.tscn"')
(target / "project.godot").write_text(config, encoding="utf-8")
print(target)
