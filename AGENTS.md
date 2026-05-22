# 仓库协作说明

## 范围

- 这是一个 OpenCode/Agent Skills 兼容技能仓库，入口文件是根目录 `SKILL.md`，脚本实现放在 `scripts/ytdlp_download.sh`。
- 用户要求修改技能行为时，通常需要同步检查 `SKILL.md`、`README.md`、`scripts/ytdlp_download.sh` 和 `tests/validate.sh`，测试脚本会校验这些文件之间的关键约束。

## 验证命令

- 首选完整验证：`tests/validate.sh`。
- 修改 shell 脚本后至少运行：`bash -n scripts/ytdlp_download.sh`，再运行 `tests/validate.sh`。
- 需要快速检查参数展开时，用脚本自带 dry-run，例如：`scripts/ytdlp_download.sh --dry-run "https://example.com/video"`；dry-run 不要求本机已安装 `yt-dlp`。

## 脚本约束

- `scripts/ytdlp_download.sh` 必须用 bash 数组构造并执行 `yt-dlp` 命令，不能引入 `eval` 或未转义字符串拼接。
- URL 只允许 `http://` 和 `https://`；新增入口或参数时不要绕过 `validate_url`。
- 默认必须追加 `--no-playlist`；只有显式 `--playlist` 或 `--playlist-range` 才允许播放列表。
- 默认不得读取浏览器 cookies；只有用户明确授权后才允许 `--cookies-browser`，且浏览器名需要白名单校验。
- 抖音 `user/self?...modal_id=...` 链接归一化为 `https://www.douyin.com/video/<modal_id>` 的行为有测试覆盖，修改 URL 处理时不要破坏。

## 技能说明约束

- `SKILL.md` frontmatter 的 `name` 必须保持 `yt-dlp-downloader`，`description` 必须以 `Use when` 开头。
- `SKILL.md` 需要同时保留 `${CLAUDE_SKILL_DIR}/scripts/ytdlp_download.sh` 和 `~/.config/opencode/skills/yt-dlp-downloader/scripts/ytdlp_download.sh` 两种脚本路径说明。
- OpenCode 场景下要引导优先调用技能脚本，不要优先裸跑 `yt-dlp`；这是 README 和测试共同约束的安全设计。

## 依赖与安装假设

- 仓库没有包管理器配置；不要新增 npm/pip 项目结构来跑现有验证。
- 脚本不会自动安装依赖，也不能执行 `sudo`；缺少 `yt-dlp` 或音频/合并所需 `ffmpeg` 时，只提示用户安装。
