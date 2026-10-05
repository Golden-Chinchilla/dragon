# 开发约定
开始前阅读 README.md 和 docs/PROJECT_PLAN.md。
当前目标：独立的精密机械蜻蜓作品与交互式三维展示。旧庭院、夜间地图和战争迷雾已按用户要求移除，不恢复旧资源。
保留可编辑 Blender 源资产与可复现生成、导出脚本。源文件放 assets/blender，网页模型放 public/assets。
使用 Yarn 4.9.1 和 yarn.lock，安装使用 yarn install --immutable，不混用包管理器。
动画直接更新场景对象，不触发每帧 UI 状态更新。
修改代码后运行 yarn lint、yarn test 和 yarn build；资产修改后重新导出并验证 GLB；涉及画面与交互必须浏览器查看。
文档区分已完成、待验证和提案，准确说明材质、烘焙内容与绑定限制。
不要提交 node_modules、dist、临时渲染、缓存或 blend 自动备份。
