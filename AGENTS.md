# 开发约定
开始前阅读 README.md 和 docs/PROJECT_PLAN.md。
当前目标：Blender 可编辑源资产 → 烘焙材质 / GLB → Three.js 正交斜俯视的庭院世界。当前为夜间连续地图与战争迷雾探索。保留月夜、暖灯、实际行走揭露、镜头跟随和探索持久化；后续改动以 docs/EXPLORATION_DESIGN.md 与验证记录为依据。
保留源资产与可复现导出脚本，源文件放 assets/blender，网页模型放 public/assets。不要恢复已清理的旧资源。
使用 Yarn 4.9.1 和 yarn.lock，安装时使用 yarn install --immutable，不混用包管理器。动画直接更新场景对象，不触发每帧 UI 状态更新。
修改代码后运行 yarn lint、yarn test 和 yarn build；资产修改后重新导出并验证 GLB，涉及画面与交互必须浏览器查看。
文档区分已完成、待验证和提案，准确说明烘焙内容与绑定限制。
不要提交 node_modules、dist、临时渲染、缓存或 blend 自动备份。
