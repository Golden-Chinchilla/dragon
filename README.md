# 雾谷 · 夜行探索世界

Blender 可编辑资产驱动的 Three.js 2.5D 世界。正交斜俯视下可见真实建筑体积、地面空间、遮挡和阴影，当前为月夜地图：蓝黑色战争迷雾、微弱月光与暖黄色提灯。

## 启动

使用 Node.js 22.16 或更新的兼容版本，通过 Corepack 固定 Yarn 4.9.1。首次使用执行 `corepack enable yarn`。

```sh
yarn install --immutable
yarn dev --port 5173
```

打开 http://127.0.0.1:5173/ 。GLB 资产已包含在 public/assets 中，启动网页无需安装 Blender。

## 编辑与重新导出

源文件：`assets/blender/courtyard.blend`。Blender 中保留独立瓦片、石板、窗框、树冠和人物四肢转轴。

```sh
yarn assets
yarn assets:exploration
yarn verify:assets
```

`assets` 使用 macOS /Applications/Blender.app 的 Blender 5.2，执行 scripts/blender/build_courtyard.py，从脚本重新生成源文件和网页模型，会覆盖当前生成资产。如直接手工修改 .blend，先将需要保留的设计同步到脚本再重新生成。

流程：程序材质 → Cycles 512px 颜色烘焙 → 源文件保存 → 静态模型按材质合并 → GLB 内嵌贴图导出。只烘焙基础颜色，光照 / 阴影在网页计算。没有全局光照、法线或粗糙度贴图烘焙。

## 操作

开场只显露出生点周围的地图。人物实际移动会揭开新区域，已经探索的区域永久保留。

- 方向键 / WASD 行走；点击已探索空地寻路。
- “沿路向前”分段走向石路、岔路与林间旅舍，便于鼠标 / 触屏体验。
- 拖动临时观察，恢复移动后镜头跟随；◇ 切换观察角度。
- 已探索的建筑可点击介绍，未知建筑不响应拾取。
- ⌂ 回到出生点并保留探索；“重新探索”清空当前地图探索与位置。
- 暂停 / 继续人物与场景动画。
- 自动保存到当前浏览器 localStorage，刷新恢复。存储不可用时显示提示并仅保留当前页面进度。

地图为 48 × 48 米有限场景，全部预加载；不是无限世界。提取源文件中的小屋与树木作为复用 GLB，移除展示底座，加入连续地形和森林道路。

## 代码结构

- src/world/assets.js：GLB 与场景配置加载。
- src/world/renderer.js：相机、灯光、阴影与窗口适配。
- src/world/world.js：人物、粒子、拾取、动画与交互。
- src/world/navigation.js：独立的碰撞与网格导航逻辑。
- src/world/exploration.js：探索网格、沿途揭露、编码与存储版本。
- src/world/fog-of-war.js：颜色 / 深度渲染目标与世界坐标迷雾合成。
- src/world/terrain.js：连续地图、道路与旅舍 / 树木复用。
- scripts/blender/export_exploration.py：从源文件提取探险地图模块。
- scripts/blender/build_courtyard.py：可复现资产生成与导出。
- scripts/verify_assets.py：GLB、纹理与转轴完整性检查。

```sh
yarn lint
yarn test
yarn verify:assets
yarn build
```

## 当前交付与限制

主屋、药草小屋、青瓦、木窗、石板路、花箱、木桶、水井、栅栏、树木、路灯、简化旅行者均为本项目生成的新资产。庭院 GLB 约 6.3 MB，10 个静态网格；人物 GLB 约 0.55 MB。数据详见 docs/asset-verification.json。

人物使用对象转轴步行动画，没有骨骼蒙皮绑定。碰撞为静态占地矩形，不是网格物理模拟。尚无建筑内部、任务、存档或正式角色美术；移动端性能仍需专项验证。字体在线加载，有系统回退。生产 JS 包仍有体积警告，后续可按加载需求优化。

## 工作流程与下一阶段

- [制作、导出与验证流程](docs/WORKFLOW.md)
- [沉浸式地图与战争迷雾方案](docs/EXPLORATION_DESIGN.md)

首版夜间战争迷雾、跟随镜头与探索存储已实现。迷雾按地面距离揭露，尚未模拟墙壁阻断视线或敌人侦察。区块流式加载仍未实现。

## Cloudflare Pages

构建命令：`yarn build`；输出目录：`dist`；根目录：项目根目录。提交 `yarn.lock`、`.yarnrc.yml` 和 `package.json`，Cloudflare 使用固定的 Yarn 版本安装依赖。模型已经导出并提交，云端构建无需 Blender。
