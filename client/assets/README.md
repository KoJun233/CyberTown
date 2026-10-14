# 客户端美术与字体

小镇地形、屋顶贴图、树木、作物、动物、风车、图标来自用户提供的 Sunnyside World V2.1。角色六种发型、南/东南/东北/北的待机与行走动画来自独立的 `sunnyside_world_chatacter_anim_human_v1.0.aseprite`，西侧朝向在运行时镜像。旧版 ARCHIVED 包已核查，当前主包覆盖所需素材，没有重复导入旧版资源。

地图是为 CyberTown 重新拼装的 640×360 场景，房屋、树、人物按脚底深度排序。背景图片不是素材包示例场景截图。农田、动物、风车用于场景装饰，不表示新增经营玩法。

独立 Aseprite 的四组方向行走动画只包含完整的 bowl hair 图层。导出时为其余五种发型使用同朝向待机图层，并按每帧身体的位移对齐头发，确保行走时保留原发型。缺少身体或有效头发的帧会直接报错。左右镜像在游戏中以脚底为中心进行，不改变图集采样区域。

准备素材：安装 Python 和 Pillow 后，在项目根目录执行 `python scripts/prepare-sunnyside-assets.py --pack <V2.1 zip> --character <aseprite>`。生成图片已随项目保存，运行/导出 Godot 游戏不依赖 Python。Godot 使用最近邻贴图过滤、等比地图缩放和独立的控件布局。

中文字体是 [Noto Sans CJK SC Regular](https://github.com/notofonts/noto-cjk/tree/main/Sans/OTF/SimplifiedChinese)，按 SIL Open Font License 1.1 分发，完整许可证位于 `fonts/OFL.txt`。未复制 Windows 系统字体。

用户提供的三个原始素材包未附带许可证文本；这里只记录来源，不推定额外分发授权。
