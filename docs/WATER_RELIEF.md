# 河湖水色与湖外地形

长江、赣江及河湖交界处统一使用湖面主水色，移除原底图中的浅蓝浅水描边，以及河道叠层中的浅水色带；实际沙岸保留。地面与河道材质共用河道范围遮罩，避免隐藏河道网格后仍露出旧描边。水位变化和水质染色继续共用，轻微抬高的河面也补偿纹理坐标偏移。

外围陆地使用公开 Terrain Tiles 的真实高程，按现有水系底图的 WGS84 范围对齐。`tools/build_poyang_elevation.py` 下载 9 张公开 z8 Terrarium 数据瓦片，按北朝上投影采样为 128×128 米制高程，保存在 `assets/geography/poyang-elevation.json`；游戏运行无需联网。地形不再使用周期正弦生成任意山包。庐山及周边丘陵与滨湖冲积平原按真实位置分布，游戏高度仍压缩至原有约 2 个世界单位的轻微幅度。

河岸、湖岸、建筑周边及彩蛋附近渐变到平地。坡面加入轻微明暗，冬季减弱阴影保持积雪亮度。陆地的坡面明暗不会作用于水面。高程分辨率及艺术高度压缩用于沙盘展示，不是精确测绘模型。

景物与接触阴影按同一高度图调整屏幕位置。相机外地面留出更大边距，覆盖抬高地形造成的屏幕位移。高度图生成不调用游戏随机数，也不改变生态或存档。

验证：沙盘 2420 项通过，73 个河湖覆盖处水面采样一致，沿两条河道采样检查无浅蓝描边；18152 个水面阴影采样无错误覆盖。测试还检查庐山高于南昌冲积平原、原有起伏幅度、彩蛋平地及缩放投影。实际截图在 `docs/screenshots/geographic-relief/`。

数据来源：[Terrain Tiles / AWS Open Data](https://registry.opendata.aws/terrain-tiles/)，获取日期 2026-10-07；[Terrarium 格式说明](https://github.com/tilezen/joerd/blob/master/docs/formats.md)、[数据来源及署名](https://github.com/tilezen/joerd/blob/master/docs/attribution.md)。Mapzen / Tilezen 汇集 SRTM 及其他公开高程来源；瓦片 URL 和地图范围记录在生成的 JSON 中。

高程数据致谢：Mapzen / Tilezen；美国地质调查局提供 SRTM、GMTED2010；NOAA 提供全球 ETOPO1。本项目对数据进行北朝上重采样、海拔截断和展示高度压缩。导出预设显式包含高程 JSON，离线包无需请求数据服务。
