# xLyra Monitor

xLyra Monitor 是一个原生 macOS 菜单栏 App，用来在状态栏里监控 xLyra 控制台。

它可以展示 OAuth 账号、站点池、API Key、请求量、Token 用量、成本、错误和路由冷却状态。项目基于 Swift Package Manager 构建，要求 macOS 14 或更新版本。

## 功能特性

- 菜单栏紧凑展示连接状态和 OAuth 可用状态。
- 菜单栏进度条展示所有可用 OAuth 账号的 5h / 7d 平均已用比例。
- 明细面板支持滚动，并按 `OAuth`、`站点`、`API Key` 分页查看。
- OAuth 账号明细展示 5h / 7d 额度、套餐、Credits、重置时间、Tokens 和成本。
- 站点池明细展示同步状态、验证状态、模型数、上游 Key 数、近期健康状态、Tokens 和成本。
- API Key 明细展示状态、额度、用量、站点数、请求数，并支持复制。
- 支持手动刷新 OAuth，也支持后台自动刷新。
- 支持从 JSON 文件导入 OAuth 账号，并可在导入时填写可选优先级。
- 支持配置刷新间隔、主题模式和开机自启动。
- 支持在设置窗口检查 GitHub Releases 更新，并下载 DMG 安装包。
- xLyra 控制台地址和 Admin Access Token 保存在本机配置文件中。

## 隐私说明

这个仓库不包含任何 xLyra 服务地址、Admin Access Token、API Key、账号数据或本机配置。

运行时，xLyra Monitor 会把用户配置保存在：

```text
~/Library/Application Support/xLyra Monitor/config.json
```

这个配置文件只会在用户自己的电脑上创建，权限为 `0600`。它不会被打进 App bundle，也不会被打进 DMG。

## 环境要求

- macOS 14 或更新版本
- Xcode Command Line Tools
- 能访问你的 xLyra 控制台
- 有效的 xLyra Admin Access Token

## 直接安装

到 Release 页面下载 DMG：

[xLyra Monitor Releases](https://github.com/z4jst/xlyra-monitor/releases)

打开 DMG 后，把 `xLyra Monitor.app` 拖到 `Applications`。

首次打开时，如果 macOS 提示来源限制，可以右键 App 选择“打开”，或到系统设置中允许打开。当前包是本地 ad-hoc 签名，还不是 Apple Developer ID 公证包。

## 首次配置

1. 打开 `xLyra Monitor.app`。
2. 点击菜单栏里的 xLyra Monitor，进入设置。
3. 填入你的 xLyra 控制台地址。
4. 填入 xLyra Admin Access Token。
5. 根据需要调整刷新间隔、主题和开机自启动。

## 本地构建

运行全部测试：

```sh
swift test
```

运行 App 冒烟测试：

```sh
swift test --filter AppSmokeTests
```

构建 Release：

```sh
swift build -c release
```

安装到本机 `~/Applications`：

```sh
scripts/install-app.sh
```

打开已安装 App：

```sh
open "$HOME/Applications/xLyra Monitor.app"
```

重启已运行的 App：

```sh
pkill -f 'XlyraMonitorApp' || true
open "$HOME/Applications/xLyra Monitor.app"
```

## 打包 DMG

生成可分发 DMG：

```sh
scripts/package-dmg.sh
```

生成文件位置：

```text
.build/dist/xLyra-Monitor-0.1.1.dmg
```

DMG 只包含：

- `xLyra Monitor.app`
- `Applications` 快捷方式

不会包含源码、测试、本机配置、构建缓存、API 文档或任何凭据。

## 接口说明

App 使用 xLyra Admin API，并通过 `X-Access-Token` 请求头传入 Admin Access Token。

## 备注

- Swift Package、target、可执行文件和 App 对外名称均已统一为 xLyra Monitor。
- 当前版本主要面向本地自用和小范围分发。
