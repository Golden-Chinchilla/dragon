# 项目制作与验证流程

更新：2026-10-04。本文记录当前已经落地的资产 / 网页流程；探索世界的下一阶段方案见 EXPLORATION_DESIGN.md。

## 1. 确认目标与美术标准

先阅读 README.md 与 PROJECT_PLAN.md，再确认用户最新需求。当前采用 Blender 源资产与 Three.js 网页分离的路线：斜俯视、真实空间、蓝绿色环境、暖窗光、有材质细节。先用小场景验证画风，再扩展地图；不恢复已清理的旧资源。

庭院是源资产样板；当前网页已扩展为 48 × 48 米夜间地图，支持跟随镜头、战争迷雾和探索存储。

## 2. 制作可编辑源资产

入口：scripts/blender/build_courtyard.py；源文件：assets/blender/courtyard.blend。

1. 创建确定随机种子的 Blender 场景，生成房屋、瓦片、石板、木窗、植物和物件。
2. 以世界尺寸建模，保留独立可编辑对象；人物使用对象父子层级与四肢转轴。
3. 制作木材、石头、灰泥、青瓦、苔地、树叶与衣料程序材质。
4. 在覆盖完整 0–1 UV 的平面上，用 Cycles 烘焙 512px 基础颜色贴图，避免 UV 空白区被其他模型采样成黑色。
5. 将贴图打包进 .blend，在网页批处理之前保存源文件。

**现有限制：**只烘焙基础颜色，不是全局光照烘焙；未输出法线 / 粗糙度贴图。人物没有骨骼蒙皮绑定，不应称为正式动画就绪角色。

## 3. 导出网页资产与配置

执行：

```sh
npm run assets
npm run assets:exploration
npm run verify:assets
```

- 人物导出为 public/assets/traveler.glb，保留对象转轴层级。
- 源文件保存之后，应用静态模型修改器、按材质合并，再导出 public/assets/courtyard.glb。
- GLB 内嵌贴图，避免网页丢失 Blender 程序节点材质。
- public/assets/courtyard.json 记录边界、占地碰撞、灯光位置、出生点与目标位置。
- scripts/verify_assets.py 检查 GLB 结构、几何、内嵌纹理、静态合并和人物转轴，并更新 docs/asset-verification.json。

重新生成会覆盖生成资产。手工编辑 .blend 时，应先将要保留的设计同步到脚本，再执行生成；脚本不会读取手工改动来继续加工。以后拆分模型时，需要同步修改导出脚本、运行时元数据及验证脚本。

## 4. 接入网页

```sh
npm install
npm run dev -- --port 5173
```

- src/world/assets.js：加载模型与配置，处理加载失败。
- src/world/renderer.js：正交相机、灯光、阴影、画面尺寸与像素比。
- src/world/world.js：场景组装、人物动作、拾取、交互与氛围动画。
- src/world/navigation.js：纯碰撞与网格寻路逻辑。
- src/main.js：启动与 UI 连接。
- src/style.css：界面、颗粒与显示层。

动画只更新场景对象。空间计算使用统一 x/z 地面坐标，y 是高度。资产由 Blender 导出时完成坐标轴转换，配置必须使用网页坐标。

## 5. 验证后再交付

代码检查：

```sh
npm run lint
npm test
npm run verify:assets
npm run build
```

涉及资产生成时额外运行 Python 语法检查与 Blender 导出。必须等资产完成后再做最终 build，否则生产目录可能缺少新资产。

浏览器检查：

1. 实际画面：模型体积、材质接缝、阴影、角色大小、不同视角与 UI 遮挡。
2. 实际交互：地面行走、建筑点击、平移、换角度、暂停、重置。
3. 控制台：运行错误、材质 / shader 警告和资源加载失败。
4. 保存实际截图作为交付证据；不把仅生成成功当作画面验证。
5. 后续迷雾增加探索持久化、遮蔽一致性、未知区域点击与性能检查。

当前纯导航测试覆盖绕障碍、拒绝非法目的地和不可达目的地。长时间操作与移动端性能尚未专项验证。

## 6. 记录完成状态

README.md 提供启动、操作、路径和限制；PROJECT_PLAN.md 记录当前目标、已完成、待验证和提案；专门设计文档记录下一阶段方案。只把有验证证据的内容标成已完成。

不提交 node_modules、dist、缓存、自动备份或临时截图。当前代码未执行自动提交或发布。

## 技术依据

- Blender 颜色烘焙：https://docs.blender.org/manual/en/latest/render/cycles/baking.html
- Three.js 模型加载：https://threejs.org/manual/pages/loading-3d-models.html
- Three.js 渲染目标：https://threejs.org/manual/pages/rendertargets.html
- Three.js 后处理：https://threejs.org/manual/pages/post-processing.html

## 夜间探索新增流程

export_exploration.py 从已保存的 .blend 提取森林旅舍和树木，并按材质合并导出。terrain.js 将这些模型组合到连续地形上，复用已加载材质。探索状态由 exploration.js 维护并存储；fog-of-war.js 使用深度纹理还原世界坐标，将未知区域替换为蓝黑色雾。探索逻辑不依赖镜头位置。

测试增加揭露单调性、沿途采样、地图边界、重复揭露不更新、保存与版本拒绝，以及点击寻路不进入未知区域。战争迷雾必须在浏览器验证，不能仅凭单元测试声称画面正确。
