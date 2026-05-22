---
name: yt-dlp-downloader
description: Use when 用户要求下载视频、下载 TikTok/抖音/YouTube/B站/Twitter/X 视频、提取音频、下载字幕、列出格式、选择画质，或明确提到 yt-dlp、视频 URL、本地保存媒体文件。
metadata:
  version: "1.0.0"
  dependencies: "yt-dlp, ffmpeg optional for audio/merge"
---

# yt-dlp 视频下载技能

使用 `yt-dlp` 安全下载用户有权保存的视频、音频、字幕和元数据。默认只保存到本地，不上传到任何第三方服务。

## 触发场景

- 用户提供视频 URL 并要求下载、保存、提取音频或下载字幕。
- 用户要求下载 TikTok、抖音、YouTube、B站、Twitter/X、Vimeo、Twitch 等平台内容。
- 用户要求列出可用清晰度、选择 720p/1080p/最佳质量或指定格式 ID。
- 用户明确提到 `yt-dlp`、`下载视频`、`提取音频`、`下载字幕`、`download video`。

## 执行原则

- 只处理用户有权下载或保存的内容；遇到版权、隐私或权限不明确的请求，先提醒风险。
- 默认下载到 `~/Downloads/yt-dlp`，除非用户指定目录。
- 默认不下载播放列表；只有用户明确要求合集、playlist 或批量下载时才启用播放列表。
- 默认不读取浏览器 cookies；只有用户明确授权，或 YouTube 等站点出现 403/需要登录时，才使用 `--cookies-browser`。
- 默认不安装依赖；缺少 `yt-dlp` 或 `ffmpeg` 时，说明需要用户安装。
- 不手写复杂 shell 命令拼接；必须优先使用本技能脚本，避免命令注入和参数转义错误。
- 在 OpenCode 中不要优先直接运行裸 `yt-dlp`；除非技能脚本不存在或用户明确要求裸命令，否则一律调用 `~/.config/opencode/skills/yt-dlp-downloader/scripts/ytdlp_download.sh`。
- 在 Claude Code 或其他 Agent Skills 兼容客户端中，优先调用 `${CLAUDE_SKILL_DIR}/scripts/ytdlp_download.sh`。
- 抖音 `user/self?...modal_id=...` 链接可直接传给脚本，脚本会自动归一化为 `https://www.douyin.com/video/<modal_id>`。

## 脚本位置

兼容 Claude Code / Agent Skills 的相对脚本路径：

```bash
${CLAUDE_SKILL_DIR}/scripts/ytdlp_download.sh
```

OpenCode 本地技能库安装后也可使用 home 相对路径：

```bash
~/.config/opencode/skills/yt-dlp-downloader/scripts/ytdlp_download.sh
```

如果需要在 OpenCode 中执行，优先使用上面的 OpenCode 路径，不要先改写成裸 `yt-dlp` 命令。

## 快速命令

下载单个视频：

```bash
${CLAUDE_SKILL_DIR}/scripts/ytdlp_download.sh "VIDEO_URL"
```

下载 TikTok/抖音视频：

```bash
${CLAUDE_SKILL_DIR}/scripts/ytdlp_download.sh "https://www.tiktok.com/@user/video/1234567890"
```

OpenCode 中下载抖音视频：

```bash
~/.config/opencode/skills/yt-dlp-downloader/scripts/ytdlp_download.sh "https://www.douyin.com/user/self?modal_id=7639305281563254986"
```

提取 MP3：

```bash
${CLAUDE_SKILL_DIR}/scripts/ytdlp_download.sh --audio "VIDEO_URL"
```

下载字幕：

```bash
${CLAUDE_SKILL_DIR}/scripts/ytdlp_download.sh --subs --sub-langs "zh-Hans,en" "VIDEO_URL"
```

限制最高 720p：

```bash
${CLAUDE_SKILL_DIR}/scripts/ytdlp_download.sh --quality 720 "VIDEO_URL"
```

列出格式：

```bash
${CLAUDE_SKILL_DIR}/scripts/ytdlp_download.sh --list-formats "VIDEO_URL"
```

用户明确授权后使用浏览器 cookies：

```bash
${CLAUDE_SKILL_DIR}/scripts/ytdlp_download.sh --cookies-browser chrome "VIDEO_URL"
```

## 常用参数

| 参数 | 用途 |
|------|------|
| `--path DIR` | 指定保存目录 |
| `--audio` | 仅提取音频，默认 MP3 |
| `--audio-format FORMAT` | 指定音频格式：`mp3`、`m4a`、`opus` 等 |
| `--subs` | 下载人工字幕 |
| `--auto-subs` | 下载自动字幕 |
| `--sub-langs LANGS` | 指定字幕语言，如 `zh-Hans,en` |
| `--quality HEIGHT` | 限制最高画质，如 `720`、`1080` |
| `--format FORMAT` | 指定 yt-dlp 格式选择器或格式 ID |
| `--list-formats` | 只列出可用格式，不下载 |
| `--thumbnail` | 下载缩略图 |
| `--metadata` | 写出 info JSON |
| `--cookies-browser SPEC` | 使用浏览器 cookies：`chrome`、`firefox`、`safari` 等；可带 profile，如 `chrome:Default` |
| `--playlist` | 允许下载播放列表 |
| `--playlist-range RANGE` | 下载播放列表范围，如 `1:5` |
| `--proxy URL` | 使用代理 |
| `--dry-run` | 打印命令但不执行 |

## 平台建议

| 平台 | 默认策略 |
|------|----------|
| TikTok/抖音 | 先直接下载；抖音提示需要 `fresh cookies` 时，再询问是否允许读取浏览器 cookies |
| YouTube | 先直接下载；403、私有或年龄限制时再请求用户授权 cookies |
| Bilibili | 先直接下载；需要登录时再让用户决定是否提供 cookies |
| Twitter/X | 先直接下载；失败时提示登录态或站点限制 |

## 错误处理

- `yt-dlp: command not found`：提示安装 `yt-dlp`，例如 `python3 -m pip install -U yt-dlp`。
- `ffmpeg not found`：音频提取或合并失败时，提示安装 `ffmpeg`。
- 抖音 `fresh cookies`：不能自动读取 cookies；先说明需要用户授权，再使用 `--cookies-browser` 重试。若默认浏览器 profile 无效，可让用户指定实际打开抖音的 profile，如 `--cookies-browser chrome:Default`。
- `HTTP 403 Forbidden`：先建议更新 `yt-dlp`，再询问是否允许读取浏览器 cookies。
- 格式不可用：运行 `--list-formats`，再按用户选择的格式下载。
- 网络或中断：重试同一命令，`yt-dlp` 会尽量断点续传。

## 安全红线

- 不使用 `eval` 执行用户输入。
- 不把用户 URL 拼接进未转义的 shell 字符串。
- 不自动读取浏览器 cookies。
- 不自动安装系统依赖或执行 `sudo`。
- 不绕过付费墙、访问控制、隐私设置或法律限制。
