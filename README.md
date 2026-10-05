# ODONATA · 机械蜻蜓

从零制作的精密机械蜻蜓，以及独立的 Three.js 交互式展示。旧庭院、地图、人物和战争迷雾资源已清理。

第二版按精密机芯方向重做：层叠传动与轴承桥板、连续铜线绕组、密排六角光学单元、不规则多边形翼脉、分片薄壳腹甲，以及带波纹护套和分节抓钩的机械足。Blender 源文件保留独立零件，网页 GLB 按材质和活动组件合并。

当前资产包含 5,506 个源网格零件，导出为 147 个网格、375,572 个三角形，GLB 约 8.43 MB。精度来自装配层级、细小间隙和加工轮廓；零件数量包括复眼单元与翼脉分段。

## 运行

需要 Node.js 22.16+，包管理器固定 Yarn 4.9.1。

```sh
corepack enable yarn
yarn install --immutable
yarn dev --port 5173
```

在 http://127.0.0.1:5173 查看。网页资产已经包含在仓库内，运行网页无需 Blender。

- 拖动旋转、滚轮缩放；触屏单指旋转、双指缩放与平移。
- 全貌、传动、翼脉、俯视切换；编号观察点可以靠近对应部位。
- 结构展开滑块分离四翼、头部、腹节和机械足；恢复到 0% 可重新装配。
- 暂停冻结机械运转，仍可观察；自动旋转控制展示镜头。
- 模型画布支持键盘方向键旋转、加减键缩放。尊重系统减少动态效果设置，默认暂停机械运动。

## 资产与验证

```sh
yarn assets
yarn verify:assets
yarn lint
yarn test
yarn build
```

`yarn assets` 使用 `/Applications/Blender.app/Contents/MacOS/Blender` 执行 `scripts/blender/build_dragonfly.py`（共用几何函数位于 `scripts/blender/mechanical_geometry.py`），生成 `assets/blender/dragonfly.blend`、`public/assets/dragonfly.glb` 以及资产统计 JSON。重复生成会覆盖这三个产物；手工调整源文件前，请先同步生成脚本。

- 源文件：完全可编辑的分件网格与命名父子层级。
- 材质：9 种 glTF PBR 材质，细节由几何表达，**没有烘焙颜色、法线、粗糙度或光照贴图**。
- 渲染：实时工作室光照、GTAO 接触遮蔽与输出色调映射。透明翼膜不参与遮蔽深度写入；没有光照烘焙。
- 动画：Three.js 驱动刚性对象转轴。没有骨骼蒙皮、气动仿真或工程级机械约束求解。当前是艺术化低速机构展示，GLB 本身不含动画片段。
- 展开：用于观察结构的分组分离，不是完整生产装配顺序。
- 字体来自 Google Fonts，网络不可用时使用本地系统字体。模型与渲染环境无需外部下载。

详细完成情况、限制与验证证据见 [项目记录](docs/PROJECT_PLAN.md)。
