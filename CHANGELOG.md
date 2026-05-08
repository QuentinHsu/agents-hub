## v0.0.3

> 本次更新让列表与设置页的展示更简洁统一，减少重复标题带来的干扰，浏览和调整内容时更清爽顺手。

### 优化改进

- **views**：
  - remove repeated list card headings
  - extract shared settings page components

## v0.0.2

> 本次更新让你在管理服务提供商和调整配置时能更快看清状态、减少重复信息，并获得更统一清爽的设置界面体验。

### 新增功能

- **api-providers**：improve provider list actions and status display

### 优化改进

- **ui**：align settings card styling
- **views**：simplify configuration detail forms

## v0.0.1

> 本次更新让你可以在 macOS 应用中更集中地管理共享 API 提供商、密钥和智能体配置，更稳妥地编辑并一键写入 Claude Code 与 Codex 设置，同时更方便地检查连接状态和获取应用更新。

### 新增功能

- initialize Agents Hub macOS app
- **profile**：support provider website links
- **app**：add Sparkle updates and DMG release workflow
- **api-providers**：manage shared API providers and keys
- **workflow**：add debug workflow for changelog generation

### 优化改进

- **settings**：centralize config constants and form helpers
- **readme**：update provider and profile docs

### 问题修复

- **profile**：defer profile saves until editing ends
- **views**：simplify sensitive provider summaries in lists
