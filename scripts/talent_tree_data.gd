extends RefCounted
## Four layers of permanent study. Rank caps count ranks, not currency spent.
const GROUPS := {
	"directions": {"name": "基础方向", "cap": 2},
	"hydrology": {"name": "水文分支", "cap": 3},
	"ecology": {"name": "生态分支", "cap": 3},
	"community": {"name": "共治分支", "cap": 3},
	"cross": {"name": "交叉研修", "cap": 3},
	"final": {"name": "终层专精", "cap": 1},
}
const NODES := [
	{"id": "origin", "name": "守护初心", "layer": 0, "slot": 2.5, "max_rank": 1, "cost": 0, "parents": [], "group": "", "desc": "研修起点，自动点亮。", "bonus": {}},
	{"id": "hydro", "name": "水文启蒙", "layer": 1, "slot": 0.5, "max_rank": 1, "cost": 1, "parents": ["origin"], "group": "directions", "desc": "开局水位 +1。", "bonus": {"start_water": 1}},
	{"id": "eco", "name": "生态启蒙", "layer": 1, "slot": 2.5, "max_rank": 1, "cost": 1, "parents": ["origin"], "group": "directions", "desc": "开局植被 +1。", "bonus": {"start_veg": 1}},
	{"id": "civic", "name": "共治启蒙", "layer": 1, "slot": 4.5, "max_rank": 1, "cost": 1, "parents": ["origin"], "group": "directions", "desc": "开局社区信任 +1。", "bonus": {"start_community": 1}},
	{"id": "hydro_water", "name": "蓄水预案", "layer": 2, "slot": 0.0, "max_rank": 2, "cost": 1, "parents": ["hydro"], "group": "hydrology", "desc": "每级：开局水位 +1。", "bonus": {"start_water": 1}},
	{"id": "hydro_quality", "name": "净水底账", "layer": 2, "slot": 1.0, "max_rank": 2, "cost": 1, "parents": ["hydro"], "group": "hydrology", "desc": "每级：开局水质 +1。", "bonus": {"start_quality": 1}},
	{"id": "eco_veg", "name": "湿地苗圃", "layer": 2, "slot": 2.0, "max_rank": 2, "cost": 1, "parents": ["eco"], "group": "ecology", "desc": "每级：开局植被 +1。", "bonus": {"start_veg": 1}},
	{"id": "eco_fish", "name": "洄游通道", "layer": 2, "slot": 3.0, "max_rank": 2, "cost": 1, "parents": ["eco"], "group": "ecology", "desc": "每级：开局鱼类 +1。", "bonus": {"start_fish": 1}},
	{"id": "civic_trust", "name": "社区联络", "layer": 2, "slot": 4.0, "max_rank": 2, "cost": 1, "parents": ["civic"], "group": "community", "desc": "每级：开局社区信任 +1。", "bonus": {"start_community": 1}},
	{"id": "civic_carry", "name": "资金留白", "layer": 2, "slot": 5.0, "max_rank": 2, "cost": 1, "parents": ["civic"], "group": "community", "desc": "每级：结转上限 +2 万。", "bonus": {"carry": 2}},
	{"id": "early_warning", "name": "协同预警", "layer": 3, "slot": 0.0, "max_rank": 2, "cost": 2, "parents": ["hydro_water", "civic_carry"], "group": "cross", "desc": "每级：危机概率降低 1 个百分点。", "bonus": {"crisis_chance": -0.01}},
	{"id": "habitat_link", "name": "栖息修复", "layer": 3, "slot": 1.0, "max_rank": 1, "cost": 2, "parents": ["hydro_quality", "eco_veg"], "group": "cross", "desc": "开局候鸟 +2。", "bonus": {"start_birds": 2}},
	{"id": "routine_monitor", "name": "常态监测", "layer": 3, "slot": 2.0, "max_rank": 2, "cost": 2, "parents": ["eco_veg", "civic_trust"], "mode": "any", "group": "cross", "desc": "每级：运营成本减少 1 万。", "bonus": {"operation": -1}},
	{"id": "careful_buy", "name": "审慎采购", "layer": 3, "slot": 3.0, "max_rank": 2, "cost": 2, "parents": ["hydro_quality", "civic_carry"], "mode": "any", "group": "cross", "desc": "每级：卡牌成本降低 1%。", "bonus": {"card_cost": -0.01}},
	{"id": "community_recovery", "name": "共管复育", "layer": 3, "slot": 4.0, "max_rank": 1, "cost": 2, "parents": ["eco_fish", "civic_trust"], "group": "cross", "desc": "开局鱼类 +1、候鸟 +1。", "bonus": {"start_fish": 1, "start_birds": 1}},
	{"id": "stable_funding", "name": "持续拨款", "layer": 3, "slot": 5.0, "max_rank": 2, "cost": 2, "parents": ["eco_fish", "civic_carry"], "mode": "any", "group": "cross", "desc": "每级：每回合拨款 +1 万。", "bonus": {"funding": 1}},
	{"id": "lake_resilience", "name": "河湖韧性", "layer": 4, "slot": 0.5, "max_rank": 1, "cost": 3, "parents": ["habitat_link", "early_warning"], "mode": "any", "group": "final", "desc": "开局水位 +5、水质 +5。", "bonus": {"start_water": 5, "start_quality": 5}},
	{"id": "habitat_expert", "name": "生境专精", "layer": 4, "slot": 2.5, "max_rank": 1, "cost": 3, "parents": ["habitat_link", "community_recovery"], "mode": "any", "group": "final", "desc": "开局植被 +5、候鸟 +5。", "bonus": {"start_veg": 5, "start_birds": 5}},
	{"id": "steady_management", "name": "稳健治理", "layer": 4, "slot": 4.5, "max_rank": 1, "cost": 3, "parents": ["careful_buy", "stable_funding", "routine_monitor"], "mode": "any", "group": "final", "desc": "每回合拨款 +5 万、结转上限 +10 万。", "bonus": {"funding": 5, "carry": 10}},
]
