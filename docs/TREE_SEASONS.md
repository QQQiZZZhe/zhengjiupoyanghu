# 树木季节动画

沿岸树、大树装饰和种植赤杉统一使用季节纹理，不再受外围陆地遮罩限制。松树保留常绿针叶，冬季在顶端与多层枝叶上积雪。

`seasonal_tree_art.gd` 从现有树冠提取叶片，补充像素枝干，并预生成 17 档叶簇遮罩。春季叶簇逐渐长出；夏季保持完整树冠；秋季渐变为暖金色；冬季金叶逐簇脱落，最后只保留枝干及枝条积雪。无需逐帧创建纹理，也不调用游戏随机数。

树木从地面换色扫描抵达的位置开始变化，局部动画持续 1.8 秒。落叶从树冠飘下，遵守彩蛋投影避让。动画使用现有暂停控制下的时间推进；减少动态效果时直接显示最终状态。

实现参考了 [Godot CanvasItem 文档](https://docs.godotengine.org/en/stable/tutorials/shaders/shader_reference/canvas_item_shader.html) 和 [gamedevserj 的遮罩溶解示例](https://github.com/gamedevserj/Godot-Shaders/blob/master/Dissolve/dissolve_shader.shader) 的透明遮罩及阈值思路。本项目为保留像素边缘，使用缓存纹理叶簇，而非整棵树透明淡出。

验证：`tree_seasons` 47 项检查通过，包括春季叶片递增、秋季金叶、冬季叶片递减与裸枝、所有树型积雪、减少动态效果和游戏状态不变；`seasonal_animation` 4063 项、`seasonal_scenery` 12078 项、`map_render` 981 项通过。后者部分测试退出时仍报告已有音频资源释放警告。

实际渲染动画：`docs/screenshots/tree-seasons/tree-cycle.gif`。放大区域从左到右为沿岸树、赤杉、松树。
