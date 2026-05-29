## 项目定位
- 英文名：`xlyra-monitor`
- 中文名：`xLyra 监控状态栏`
- 项目类型：macOS 原生菜单栏 App，基于 Swift Package Manager。
- 核心目标：在 macOS 状态栏展示 xLyra 控制台的站点池、OAuth 账号、API Key、请求、用量、错误和冷却状态，并提供刷新、设置、主题切换、开机自启动、检查更新等本地能力。

## 规则优先级
- 不再强制读取个人机器上的全局规则文件；以当前会话的系统/开发者指令和本项目 `AGENTS.md` 为准。
- 若用户临时给出与本文不冲突的要求，按用户要求执行。
- 若用户要求与本文冲突，先说明冲突点，再按更高优先级指令处理。

## 本地开发规则
- 主要源码目录：
  - `Sources/XlyraMonitorApp/`：macOS App、菜单栏、设置窗口、主题、API 客户端、更新检查和视图模型。
  - `Tests/XlyraMonitorAppTests/`：App 层测试。
- 修改 UI 前先确认菜单栏空间限制；状态栏内容优先保持紧凑、稳定、可读。
- 菜单栏 label 若需要复杂布局，优先使用稳定的 `NSImage` 渲染方案；SwiftUI 原生布局在 `MenuBarExtra` 中可能被系统压缩。
- 明细页滚动区内不要放会让用户迷失上下文的固定标题；例如 `OAuth 账号`、`站点池`、`API Key` 这类标题应固定在滚动区外。
- 每次做优化、修复或重构时，要检查本次改动触达范围内是否存在冗余、过时或已失效的代码、文档和脚本；能安全清理的直接清理，不能确定的在最终回复中说明风险。
- 构建产物 `.build/`、`.build/app/`、`.build/dist/` 只作为本地输出，不作为源码交付内容。

## 常用命令
- 运行全部测试：`swift test`
- 运行 App 冒烟测试：`swift test --filter AppSmokeTests`
- Release 构建：`swift build -c release`
- 安装到本机应用目录：`scripts/install-app.sh`
- 打包 DMG：`scripts/package-dmg.sh`
- 重启已安装 App：
  ```sh
  pkill -f 'XlyraMonitorApp' || true
  open "$HOME/Applications/xLyra Monitor.app"
  ```

## 本地交付约定
- 需要交付本机可用 App 时，运行 `scripts/install-app.sh` 并重启 `$HOME/Applications/xLyra Monitor.app`。
- 用户要求“打包一份到下载目录”时，先运行 `scripts/package-dmg.sh`，再把 `.build/dist/xLyra-Monitor-<version>.dmg` 复制到 `$HOME/Downloads/`；默认发版或 push 不复制 DMG 到 Downloads。
- 本地安装、重启、复制到 Downloads、测试命令和构建命令属于执行记录，只在最终回复中说明，不写进 GitHub Release 更新日志。

## GitHub 发布约定
- 只有用户明确要求更新 GitHub、发布 Release、发版、上传 DMG，或明确说 `push` / `推上去` / `推送` 时，才执行远端推送和 Release 操作。
- 用户说 `push` / `推上去` / `推送` 时，默认含义是：提交当前改动、推送 GitHub、打包 DMG、创建版本 tag，并发布 GitHub Release；不要只执行 `git push`，也不要把 DMG 复制到 Downloads，除非用户明确要求。
- 发版时按当前 App 版本创建 tag，例如 `v0.1.2`，并上传对应 DMG。
- GitHub Release 更新日志只写用户可感知的 App 变化、修复和必要的下载校验信息。
- GitHub Release 更新日志不要记录本地操作流水，例如本地安装、重启、复制 DMG 到 Downloads、运行测试、构建、打 tag、推送、使用 token 等。
- 不在仓库、Release 正文或提交信息中保存 GitHub token、xLyra Access Token、API Key、本机路径中的敏感凭据或用户私有配置。

## Unraid 自动拉取/部署
- `UNRAID_AUTO_DEPLOY=false`
- 本项目是 macOS 本地原生 App，不接 Unraid 自动部署链路。
- 不触发 `post-receive -> deploy-webhook -> deploy.sh`。

## 验收要求
- 修改业务逻辑后至少运行相关测试；改动范围不明确时运行 `swift test`。
- 修改菜单栏显示、明细页滚动、排序、xLyra 数据读取、开机自启动、主题设置、更新检查等 App 行为后，至少运行 `swift test --filter AppSmokeTests` 和 `swift build -c release`。
- 需要交付本机可用 App 时，必须说明是否已安装和重启。
- 最终回复必须说明已运行的验证命令，以及是否安装、重启、打包、推送或发布 Release。
