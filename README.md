# yt-dlp 视频下载技能

这是一个符合 Agent Skills 和 Claude Code Skills 目录结构的技能：目录内包含必需的 `SKILL.md`，并通过 `scripts/ytdlp_download.sh` 封装 `yt-dlp`。

## 安装位置

源码目录示例：

```text
~/workspace/skills/yt-dlp-downloader/
```

OpenCode 本地技能库安装目录：

```text
~/.config/opencode/skills/yt-dlp-downloader/
```

目录结构：

```text
yt-dlp-downloader/
├── SKILL.md
├── README.md
├── LICENSE
├── scripts/
│   └── ytdlp_download.sh
└── tests/
    └── validate.sh
```

## 依赖

必需：

```bash
python3 -m pip install -U yt-dlp
```

音频提取或格式合并常用：

```bash
brew install ffmpeg
```

脚本不会自动安装依赖，也不会执行 `sudo`。

## 常用命令

下载单个视频：

```bash
scripts/ytdlp_download.sh "VIDEO_URL"
```

下载 TikTok 视频：

```bash
scripts/ytdlp_download.sh "https://www.tiktok.com/@user/video/1234567890"
```

提取 MP3：

```bash
scripts/ytdlp_download.sh --audio "VIDEO_URL"
```

限制最高 1080p：

```bash
scripts/ytdlp_download.sh --quality 1080 "VIDEO_URL"
```

列出格式：

```bash
scripts/ytdlp_download.sh --list-formats "VIDEO_URL"
```

Dry-run 检查命令但不下载：

```bash
scripts/ytdlp_download.sh --dry-run "VIDEO_URL"
```

## 安全设计

- 脚本使用 bash 数组执行命令，不使用 `eval`。
- URL 只接受 `http://` 和 `https://`。
- 默认添加 `--no-playlist`，避免误下载整个播放列表。
- 浏览器 cookies 只在显式传入 `--cookies-browser` 时使用。
- 支持的 cookies 浏览器为 `chrome`、`firefox`、`safari`、`edge`、`brave`、`opera`。
- 不绕过付费墙、访问控制、隐私设置或法律限制。

## 验证

```bash
tests/validate.sh
```

验证项包括：

- `SKILL.md` frontmatter 和关键词。
- 脚本语法 `bash -n`。
- dry-run 默认包含 `--no-playlist`。
- 播放列表模式不会追加 `--no-playlist`。
- 非法浏览器、非法 URL、非法画质会失败。
- 脚本中不存在 `eval`。

## 规范依据

- Agent Skills：每个技能是一个目录，入口为 `SKILL.md`，至少包含 `name` 和 `description` 元数据。
- Claude Code Skills：支持 `SKILL.md` frontmatter、支持文件和脚本目录；说明主体保持简洁，详细逻辑放到脚本或 README。
- OpenCode：全局技能目录为 `~/.config/opencode/skills/<name>/SKILL.md`。
