# Rive 实验

两个 Rive CLI 项目：根目录是水母（下文），[tvmenu/](tvmenu/README.md) 是复刻的电视首页。根项目的 `rive.yaml` 排除了 `tvmenu`，两边各自 `rive <dir>` 预览。

# Jellyfish

一只深海水母，用 Rive CLI 从 RML、Luau 和 WGSL 构建。鼠标悬停时它会缓慢靠近，点击时收缩并逃开。

## 做法

画面从上到下分六层，和 Philippe Roy 锦鲤池的思路一致：矢量分层画出主体，骨骼蒙皮做连续变形，着色器做水体，最后一层调色。

| 层 | 内容 | 实现 |
|---|---|---|
| Grade | 暗角、顶部薄雾、每帧刷新的胶片颗粒 | `grade.luau` + `grade.wgsl`，全屏三角形，srcOver 叠在最上面 |
| Input | 指针 → view model 数值 | `drift.luau` |
| Beads | 沿触手下行的发光珠 | 每根触手一颗，`FollowPathConstraint` 的 `distance` 打关键帧 |
| Jelly | 伞盖 9 层矢量，两根骨骼蒙皮 | 伞缘光、辐管、高光、内脏、内膜、本体、边缘增厚、底部阴影、外发光 |
|       | 13 根触手 + 4 条口腕 | 每根一条锥形闭合路径，蒙皮到 4–5 节骨链，骨骼旋转打关键帧 |
| Snow | 海雪和气泡 | `snow.luau`，Renderer 直接画 |
| Water | 深度渐变、漂移雾、斜向光束、焦散 | `water.luau` + `water.wgsl` |

伞盖呼吸不是缩放整组，而是两根骨骼（Apex、Hem）各自打 scale/y 关键帧，顶点按高度在两者之间混权重，所以伞缘收缩得比顶部多、还晚一拍。

## 文件

| 文件 | 作用 |
|---|---|
| `tools/gen_scene.py` | 生成器。几何、权重打包、骨链、关键帧波形都在这里，改参数后重新生成 |
| `scene.rml` | 生成产物，不要手改 |
| `drift.luau` | 指针逻辑，写 `jellyX/Y`、`jellyTilt`、`dartScaleX/Y`、`tentacleSwing/Stretch` |
| `water.luau` / `water.wgsl` | 水体背景；每帧从 view model 读颜色和光线参数 |
| `grade.luau` / `grade.wgsl` | 调色层；读 `grain`、`vignette` |
| `snow.luau` | 海雪、气泡 |

## 可调设置（view model `Scene`）

颜色都是 ARGB，alpha 是设置的一部分：

| 属性 | 含义 | 默认 |
|---|---|---|
| `waterTop` / `waterBottom` | 水体上下色 | `FF0A2A48` / `FF02060E` |
| `lightColor` | 光束、焦散、雾的颜色 | `FFA9DCFF` |
| `lightIntensity` | 光束亮度 0–1 | `0.65` |
| `lightAngle` | 光束角度，度 | `-14` |
| `bellColor` / `bellEdge` | 伞盖中心 / 边缘与口腕 | `8C5FC4DE` / `3A8FE0F2` |
| `glowColor` | 伞缘、辐管、触手、外发光 | `FF6FE6FF` |
| `coreColor` | 内脏暖光 | `FFFFB063` |
| `glowStrength` | 外发光强度 0–1 | `0.75` |
| `grain` | 颗粒强度 | `0.07` |
| `vignette` | 暗角强度 | `0.6` |

其余数值由 `drift.luau` 每帧写入，不要手动设。

## 工作流

```bash
python3 tools/gen_scene.py
```
```bash
rive . --verify
```
```bash
rive inspect . --summary
```
```bash
rive . --screenshot=build/f.png --advance=90
```
```bash
rive .
```

试一组暖色：

```bash
rive . --screenshot=build/warm.png --advance=90 --data=glowColor=FFFFA060 --data=coreColor=FFFFE6B8 --data=waterTop=FF3A1030 --data=lightColor=FFFFC890 --data=bellColor=8CD88A70 --data=lightAngle=16
```

## 限制

- 本地构建的脚本未签名，网页运行时会拒绝；发布到网页要用 `rive . --publish=web`。
- 着色器在 Metal 上验证过，WebGPU 校验更严格，上线前需在浏览器确认。
- `.rev` 能在 Rive Editor 打开，但蒙皮权重是生成器算的，编辑器里改完再拉回来要重新对一遍。
