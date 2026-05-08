[English](README.md) | 简体中文

<div align="center">

<img src="Docs/static/logo.png" width="220" alt="Agents Hub logo" style="border-radius: 48px;" />

<p>
  <img alt="Platform" src="https://img.shields.io/badge/macOS-15%2B-111111?style=flat&logo=apple" />
  <img alt="Swift" src="https://img.shields.io/badge/Swift-6.3-F05138?style=flat&logo=swift" />
  <img alt="Build" src="https://img.shields.io/badge/Build-SwiftPM-0A84FF?style=flat" />
  <img alt="i18n" src="https://img.shields.io/badge/i18n-zh--Hans%20%7C%20en-34C759?style=flat" />
  <img alt="Version" src="https://img.shields.io/github/v/release/QuentinHsu/agents-hub?style=flat&logo=github" />
  <img alt="Downloads" src="https://img.shields.io/github/downloads/QuentinHsu/agents-hub/total?style=flat&logo=dropbox&logoColor=white&color=green" />
</p>

# Agents Hub

一个原生 macOS 应用，用来管理可复用的 API 供应商，并将 Claude Code 或 Codex 配置应用到本地 CLI 配置文件。

</div>

---

## 系统要求

- macOS 15 或更高版本
- 如果需要让 Agents Hub 将配置应用到对应工具，需要安装 Claude Code CLI 和/或 Codex CLI

Agents Hub 会在本地保存供应商和配置，并把选中的 Claude Code 或 Codex 配置写入各工具现有的配置位置。

应用支持通过 Sparkle 自动更新。你也可以从应用菜单或 `设置` -> `关于` 手动检查更新。

## 快速开始

1. 打开 Agents Hub。
2. 打开 `供应商`，添加或编辑供应商的 Base URL、供应商官网，以及一个或多个具名 API Key。
3. 在侧边栏选择 `Claude Code` 或 `Codex`。
4. 点击 `添加配置`。
5. 选择 `API 供应商`；如果该供应商有多个 Key，再选择 `供应商 Key`，然后设置该智能体的模型字段。
6. 点击 `设为当前` 应用选中的配置。
7. 打开 `概览`，点击 `刷新` 检查 endpoint 状态和本地工具版本。

## 管理供应商

供应商是 Claude Code 和 Codex 配置都可以复用的 API 连接记录。

- 保存供应商名称、Base URL 和可选的供应商官网。
- 为一个供应商添加多个具名 Key，用于不同渠道或账号。
- 在 `供应商` 页面复制和删除供应商。
- 删除供应商或 Key 时，相关配置会自动改用后备供应商。

## 管理 API 配置

- 分别为 Claude Code 和 Codex 保存配置列表。
- 支持新增、复制、删除和重命名智能体配置。
- 每个配置可选择一个共享的 API 供应商和供应商 Key。
- 每个配置可保存模型和供应商专属模型选项。
- 每个智能体可以标记一个当前配置。
- 可以在 Finder 中显示目标配置文件。

API Key 会通过供应商 Key 保存在本地 Agents Hub 状态文件中，并在应用配置时写入目标 CLI 配置文件。

## 配置 Claude Code

Claude Code 配置会写入 `~/.claude/settings.json`。

| 字段 | 写入内容 |
| --- | --- |
| `settings.model` | 选中配置的模型 |
| `env.ANTHROPIC_AUTH_TOKEN` | 选中配置的 API Key |
| `env.ANTHROPIC_BASE_URL` | 选中配置的 Base URL |
| `env.ANTHROPIC_MODEL` | 选中配置的模型 |
| `env.ANTHROPIC_DEFAULT_OPUS_MODEL` | 默认 Opus 模型 |
| `env.ANTHROPIC_DEFAULT_SONNET_MODEL` | 默认 Sonnet 模型 |
| `env.ANTHROPIC_DEFAULT_HAIKU_MODEL` | 默认 Haiku 模型 |

应用 Claude Code 配置时，Agents Hub 会移除 `env.ANTHROPIC_API_KEY`，让 Claude Code 使用所选供应商 Key 对应的 `ANTHROPIC_AUTH_TOKEN`。

Claude Code 还有一个共享的 `跳过 Claude 初始引导` 设置。启用后，Agents Hub 会更新 `~/.claude.json`，并将 `hasCompletedOnboarding` 设置为 `true`。

## 配置 Codex

Codex 配置会写入 `~/.codex/config.toml` 和 `~/.codex/auth.json`。

| 文件 | 写入内容 |
| --- | --- |
| `~/.codex/config.toml` | 选中的模型和 `model_providers.agents-hub` 供应商设置 |
| `~/.codex/auth.json` | 选中配置的 `OPENAI_API_KEY` |

Agents Hub 会以 `wire_api = "responses"` 和 `requires_openai_auth = true` 写入 Codex 配置。受管理的 Codex provider ID 始终写为 `model_providers.agents-hub`；显示名称可以使用 `Agents Hub`，也可以使用选中的配置名称。

## 检查本地状态

`概览` 页面会显示：

- 当前 Claude Code 与 Codex 配置的 endpoint 健康状态和延迟
- 本地 `claude` 与 `codex` CLI 版本
- 已安装的 Claude Desktop 与 Codex Desktop app 版本

点击 `刷新` 可以重新执行 API 检查和本地版本检测。

## 配置文件

| 路径 | 用途 |
| --- | --- |
| `~/.config/agents-hub/profiles.json` | Agents Hub 供应商、Key、配置和共享设置存储 |
| `~/.claude/settings.json` | Claude Code 配置写入的 Claude Code 设置 |
| `~/.claude.json` | 启用共享设置时写入的 Claude Code onboarding 状态 |
| `~/.codex/config.toml` | Codex 模型与供应商配置 |
| `~/.codex/auth.json` | Codex API Key 认证内容 |

## 本地构建

运行应用：

```sh
make run
```

构建 release 可执行文件：

```sh
make build
```

构建 app bundle：

```sh
make app
```

构建 DMG 安装包：

```sh
make dmg
```

安装到 `/Applications`：

```sh
make install
```

`app` 和 `install` target 默认使用 `../../open-source/workflow/release-kits/macos/swiftpm-sparkle` 下的 `Scripts/build.sh`。如果 release kit 位于其他路径，可以覆盖 `RELEASE_KIT_DIR`：

```sh
make app RELEASE_KIT_DIR=/path/to/swiftpm-sparkle
```

## Star 历史

[![Star History Chart](https://starchart.cc/QuentinHsu/agents-hub.svg?variant=adaptive)](https://starchart.cc/QuentinHsu/agents-hub)

## 许可证

[MIT](LICENSE)
