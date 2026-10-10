# Card.zip 卡牌素材更新清单

来源：美术同学提供的 Card.zip（2026-10-10）。共 23 张 PNG：15 张完整模板及图例，8 张空白备份。

## 修改范围

- 52 张普通行动卡：替换生态、社会、管理底图；金额颜色取自图例，RGB(56,68,53)，即 #384435。
- 知识卡：九类条目按分类重排，并使用各自的完整牌底；保留知识内容、收集 ID 和触发条件。
- 未收集卡和彩蛋：替换对应完整美术素材。
- 紧急调度：基于新空白备份及三类手牌标题制作无金额牌底，重新生成全部 52 张专用卡。
- 原始图例和空白备份归档至 tools/art_sources/card-20261010/，便于后续重建。

## 每个知识条目的对应牌底

| 分类 | 条目 | 牌底 |
| --- | --- | --- |
| 地理 | 认识鄱阳湖 | assets/art/knowledge/geography.png |
| 地理 | 五河汇入一湖 | assets/art/knowledge/geography.png |
| 地理 | 湖口：江湖相连的通道 | assets/art/knowledge/geography.png |
| 地理 | 会变大小的湖 | assets/art/knowledge/geography.png |
| 地理 | 碟形湖：大湖里的小湖 | assets/art/knowledge/geography.png |
| 地理 | 湖泊如何调蓄洪水 | assets/art/knowledge/geography.png |
| 植物 | 苦草 | assets/art/knowledge/plants.png |
| 植物 | 苔草：草洲上的绿色食堂 | assets/art/knowledge/plants.png |
| 植物 | 芦苇与南荻 | assets/art/knowledge/plants.png |
| 植物 | 莲与藕的秘密 | assets/art/knowledge/plants.png |
| 鸟类 | 白鹤 | assets/art/knowledge/birds.png |
| 鸟类 | 小天鹅 | assets/art/knowledge/birds.png |
| 鸟类 | 东方白鹳 | assets/art/knowledge/birds.png |
| 鸟类 | 白枕鹤 | assets/art/knowledge/birds.png |
| 鸟类 | 鄱阳湖的雁类 | assets/art/knowledge/birds.png |
| 水生动物 | 长江江豚 | assets/art/knowledge/aquatic.png |
| 外来物种 | 福寿螺综合防控 | assets/art/knowledge/invasive.png |
| 机制 | 水质与苦草 | assets/art/knowledge/mechanisms.png |
| 机制 | 鱼儿的江湖旅行 | assets/art/knowledge/mechanisms.png |
| 机制 | 湿地植物的分布带 | assets/art/knowledge/mechanisms.png |
| 机制 | 湿地里的食物联系 | assets/art/knowledge/mechanisms.png |
| 机制 | 水鸟需要适宜的水深 | assets/art/knowledge/mechanisms.png |
| 机制 | 小微湿地帮助净水 | assets/art/knowledge/mechanisms.png |
| 机制 | 湿地也能储存碳 | assets/art/knowledge/mechanisms.png |
| 机制 | 雨水带来的面源污染 | assets/art/knowledge/mechanisms.png |
| 机制 | 鸟脚上的“身份证” | assets/art/knowledge/mechanisms.png |
| 机制 | 水下也有噪声 | assets/art/knowledge/mechanisms.png |
| 保护行动 | 科学放流，拒绝随意放生 | assets/art/knowledge/conservation.png |
| 保护行动 | 文明观鸟 | assets/art/knowledge/conservation.png |
| 保护行动 | 发现伤病鸟怎么办 | assets/art/knowledge/conservation.png |
| 保护行动 | 草洲不是越野场 | assets/art/knowledge/conservation.png |
| 案例 | 苦草病害的因果 | assets/art/knowledge/cases.png |
| 案例 | 极端干旱的连锁影响 | assets/art/knowledge/cases.png |
| 案例 | 渔网和鱼线的隐患 | assets/art/knowledge/cases.png |
| 管理策略 | 野生动物致害补偿 | assets/art/knowledge/management.png |
| 管理策略 | 候鸟迁飞通道 | assets/art/knowledge/management.png |
| 管理策略 | 怎样调查候鸟 | assets/art/knowledge/management.png |
| 管理策略 | 十年禁渔保护了什么 | assets/art/knowledge/management.png |
| 管理策略 | 候鸟食堂怎样建 | assets/art/knowledge/management.png |
| 管理策略 | 从捕鱼人到护鱼员 | assets/art/knowledge/management.png |
| 彩蛋 | 狄鑫斛 | assets/art/knowledge/easter-egg.png |
| 未收集 | 所有尚未解锁条目 | assets/art/knowledge/unknown.png |

## 验证目标

- 分类完整覆盖全部条目；每类纹理与对应新素材逐像素一致。
- 金额文字使用 #384435，写入位置与图例一致；标题不覆盖类别或纸夹。
- 图鉴和详情共享分类牌底；游戏内彩蛋收集弹窗使用新的完整彩蛋牌面。
- 紧急调度不显示普通费用便签，普通行动卡费用及效果保持不变。

## 重建

运行 `python tools/import_card_art.py`（可选参数为新的 Card.zip 路径），在 Godot 中导入后运行 `tools/bake_dispatch_deck.tscn`，再导入生成的 52 张卡牌。

新知识牌面的 `process/fix_alpha_border` 设为 false，防止引擎自动改变美术提供的透明边缘像素；所有卡牌保持最近邻采样。

## 验证结果

- 素材及分类检查：352 项，0 失败。覆盖 41 个知识条目的分类顺序、九套完整牌底、未知及彩蛋素材、全部普通档位金额颜色，以及 52 张调度素材重建一致性。
- 真实窗口集成检查：258 项，0 失败。覆盖调度、普通牌库、知识图鉴和分类详情。
- 知识卡界面检查：244 项，0 失败。覆盖收集状态、全部详情、彩蛋闪卡、960×540 与 1280×720 布局。
- 预览及真实窗口截图保存在 `docs/screenshots/card-assets-20261010/`。
