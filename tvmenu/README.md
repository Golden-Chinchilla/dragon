# TV Menu

复刻 Philippe Roy 的电视首页（"TV menu upgraded with some 3D and shaders"），用 Rive CLI 从 RML、Luau 和 WGSL 构建。方向键选应用，下键进入输入源行，上键或 Back 回到应用行。

## 做法

| 部分 | 实现 |
|---|---|
| 文字 | 全部是 Rive `Text`，绑定到 `Menu` view model：标题、副标题、计数、印花名、时钟、卡片标签、提示 |
| 印花 | 程序生成，`print.wgsl` 在首帧把 10 张印花各渲染一次到 640×400 纹理；每个应用一组参数：4 色调色板、图案种类（点 / 十字 / 鳞 / 条纹 / 方块）、种子、缩放、墨迹量 |
| 卡片 | `card.wgsl`：一个带厚度的盒子，每张卡片一次 `drawIndexed`，uniform 用动态偏移；正面采样印花纹理加斜角边框，选中时玻璃高光扫过、边缘按配色发光；倒影是同一个盒子绕地面线翻转半周，按离地高度淡出 |
| 背景 | `bg.wgsl`，按屏幕 1/4 分辨率渲染：当前印花纹理放大、布料式褶皱位移、七次采样失焦、左下压暗、选中卡片在地面投下彩光、暗角。切换是排队的"烧蚀"：新印花沿噪声边缘从一侧烧穿旧印花，边缘有一道带配色的亮带，每次约 1.1 秒，排队执行，所以快速导航时背景会慢一拍，和原作一致 |
| 颗粒 | `grade.wgsl`，全分辨率，叠在卡片画布上 |
| 交互 | `menu.luau`：键盘、鼠标悬浮（划过即选中）、点击（点已选中的卡片触发扫光），维护选中项、滚动窗口、背景队列，并把文字和标签位置写进 view model |

印花在他那里是画出来的 10 张图；这里用程序图案代替，这是和原作最大的差别。

性能：印花只算一次，背景 1/4 分辨率，每帧真正逐像素的开销只剩背景的 3 层噪声和 14 次纹理采样（在 1/4 尺寸上）加卡片的一次采样。

## 文件

| 文件 | 作用 |
|---|---|
| `scene.rml` | 界面排版、view model、字体、脚本层 |
| `menu.luau` | 数据（10 个应用、5 个输入源）、键盘、动画、两个 GPU 画布 |
| `print.wgsl` / `bg.wgsl` / `card.wgsl` / `grade.wgsl` | 印花、背景、卡片、颗粒四个着色器 |
| `Lora.ttf` `Inter.ttf` `JetBrainsMono.ttf` | 标题、正文、小字（来自 Rive CLI 样例，OFL 授权） |

## 工作流

```bash
rive . --verify
```
```bash
rive inspect . --summary
```
```bash
rive . --screenshot=build/a.png --advance=30
```
```bash
rive . --screenshot=build/b.png --advance=10 --key=right:down --advance=40
```
```bash
rive .
```

键码（GLFW）：左 263、右 262、上 265、下 264、回车 257、Esc 256、退格 259。

## 限制

- 脚本未签名，网页运行时会拒绝；要上网页用 `rive . --publish=web`。
- 着色器只在 Metal 上验证过。
- 时钟用 `os.date`，截图模式下也会显示当前时间。
