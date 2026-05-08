English | [简体中文](README.zh-CN.md)

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

A native macOS app for managing Claude Code and Codex API profiles and applying them to local CLI configuration files.

</div>

---

## Requirements

- macOS 15 or later
- Claude Code CLI and/or Codex CLI, if you want Agents Hub to apply profiles to those tools

Agents Hub stores profiles locally and writes the selected profile into each tool's existing configuration location.

The app supports automatic updates via Sparkle. You can also check for updates manually from the app menu or `Settings` -> `About`.

## Quick Start

1. Open Agents Hub.
2. Select `Claude Code` or `Codex` from the sidebar.
3. Click `Add Configuration`.
4. Fill in the profile name, base URL, API key, and model.
5. Click `Set Current` to apply the selected profile.
6. Open `Overview` and click `Refresh` to check endpoint status and local tool versions.

## Manage API Profiles

- Keep separate saved profile lists for Claude Code and Codex.
- Add, duplicate, delete, and rename configurations.
- Store base URL, API key, model, and provider-specific model options per profile.
- Mark one profile as current for each provider.
- Reveal the target configuration files in Finder.

API keys are stored in the local Agents Hub profile file and are also written to the target CLI configuration files when a profile is applied.

## Configure Claude Code

Claude Code profiles are written to `~/.claude/settings.json`.

| Field | Written value |
| --- | --- |
| `settings.model` | selected profile model |
| `env.ANTHROPIC_AUTH_TOKEN` | selected profile API key |
| `env.ANTHROPIC_BASE_URL` | selected profile base URL |
| `env.ANTHROPIC_MODEL` | selected profile model |
| `env.ANTHROPIC_DEFAULT_OPUS_MODEL` | default Opus model |
| `env.ANTHROPIC_DEFAULT_SONNET_MODEL` | default Sonnet model |
| `env.ANTHROPIC_DEFAULT_HAIKU_MODEL` | default Haiku model |

Claude Code also has a shared `Skip Claude Onboarding` setting. When enabled, Agents Hub updates `~/.claude.json` and sets `hasCompletedOnboarding` to `true`.

## Configure Codex

Codex profiles are written to `~/.codex/config.toml` and `~/.codex/auth.json`.

| File | Written value |
| --- | --- |
| `~/.codex/config.toml` | selected model and `model_providers.agents-hub` provider settings |
| `~/.codex/auth.json` | `OPENAI_API_KEY` from the selected profile |

Agents Hub writes Codex profiles with `wire_api = "responses"` and `requires_openai_auth = true`. The managed Codex provider ID is always `model_providers.agents-hub`; its display name can be either `Agents Hub` or the selected profile name.

## Check Local Status

The `Overview` page shows:

- endpoint health and latency for the current Claude Code and Codex profiles
- local `claude` and `codex` CLI versions
- installed Claude Desktop and Codex Desktop app versions

Use `Refresh` to re-run API checks and local version detection.

## Configuration Files

| Path | Purpose |
| --- | --- |
| `~/.config/agents-hub/profiles.json` | Agents Hub profile storage |
| `~/.claude/settings.json` | Claude Code settings written by Claude Code profiles |
| `~/.claude.json` | Claude Code onboarding state when the shared setting is enabled |
| `~/.codex/config.toml` | Codex model and provider configuration |
| `~/.codex/auth.json` | Codex API key auth payload |

## Build Locally

Run the app:

```sh
make run
```

Build a release binary:

```sh
make build
```

Build the app bundle:

```sh
make app
```

Build the DMG installer:

```sh
make dmg
```

Install the built app into `/Applications`:

```sh
make install
```

The `app` and `install` targets use `Scripts/build.sh` from `../../open-source/workflow/release-kits/macos/swiftpm-sparkle` by default. Override `RELEASE_KIT_DIR` if that release kit lives somewhere else:

```sh
make app RELEASE_KIT_DIR=/path/to/swiftpm-sparkle
```

## Star History

[![Star History Chart](https://starchart.cc/QuentinHsu/agents-hub.svg?variant=adaptive)](https://starchart.cc/QuentinHsu/agents-hub)

## License

[MIT](LICENSE)
