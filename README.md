# xLyra Monitor

xLyra Monitor is a native macOS menu bar app for watching an xLyra control panel from the status bar.

It shows the health of OAuth accounts, site pools, API keys, request volume, token usage, cost, errors, and route cooldowns. It is built with Swift Package Manager and targets macOS 14 or newer.

## Features

- Compact menu bar indicator for connectivity and OAuth availability.
- Menu bar usage bars for average OAuth 5h and 7d usage across available accounts.
- Scrollable detail panel with OAuth, Sites, and API Key tabs.
- OAuth account details with 5h / 7d quota, plan label, credits, reset time, tokens, and cost.
- Site pool details with sync status, validation status, model count, upstream key count, recent health, tokens, and cost.
- API Key details with status, quota, usage, site count, request count, and copy support.
- Manual OAuth refresh plus automatic background refresh.
- Configurable refresh interval, theme mode, and launch-at-login setting.
- Local configuration file storage for xLyra console URL and Admin Access Token.

## Privacy

The repository does not include any xLyra server address, Admin Access Token, API key, account data, or local app configuration.

At runtime, xLyra Monitor stores user configuration in:

```text
~/Library/Application Support/xLyra Monitor/config.json
```

The configuration file is created locally on the user's machine with `0600` permissions. It is not part of the app bundle or DMG package.

## Requirements

- macOS 14 or newer
- Xcode command line tools
- Network access to an xLyra control panel
- A valid xLyra Admin Access Token

## Build And Test

Run all tests:

```sh
swift test
```

Run the app smoke tests:

```sh
swift test --filter AppSmokeTests
```

Build the release binary:

```sh
swift build -c release
```

## Install Locally

Build and install the app into `~/Applications`:

```sh
scripts/install-app.sh
```

Open the installed app:

```sh
open "$HOME/Applications/xLyra Monitor.app"
```

Restart an already running copy:

```sh
pkill -f 'Sub2APIQuotaApp' || true
open "$HOME/Applications/xLyra Monitor.app"
```

## Package A DMG

Create a distributable DMG:

```sh
scripts/package-dmg.sh
```

The generated DMG is written to:

```text
.build/dist/xLyra-Monitor-0.1.0.dmg
```

The DMG contains only:

- `xLyra Monitor.app`
- an `Applications` shortcut

It does not include source files, tests, local configuration, build caches, API documentation, or credentials.

## First Run

1. Open `xLyra Monitor.app`.
2. Click the menu bar item and open Settings.
3. Enter your xLyra control panel URL.
4. Enter your xLyra Admin Access Token.
5. Adjust refresh interval, theme, and launch-at-login as needed.

## Notes

- The app uses xLyra Admin APIs with the `X-Access-Token` request header.
- The current package is ad-hoc signed for local distribution. If you distribute it outside your own machines, macOS Gatekeeper may require users to right-click and choose Open, or approve the app in System Settings.
- The Swift package name still contains the historical `Sub2APIQuota` target names for compatibility, while the app product is branded as xLyra Monitor.
