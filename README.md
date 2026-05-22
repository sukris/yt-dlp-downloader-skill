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

默认行为等价于 `--preset compatible`：优先下载单个 MP4 兼容文件，目标最高 1080p，适合 QuickTime、手机和常见播放器。

最高质量：

```bash
scripts/ytdlp_download.sh --preset best "VIDEO_URL"
```

手机/微信友好：

```bash
scripts/ytdlp_download.sh --preset mobile "VIDEO_URL"
```

快速小文件测试：

```bash
scripts/ytdlp_download.sh --preset small "VIDEO_URL"
```

下载 TikTok 视频：

```bash
scripts/ytdlp_download.sh "https://www.tiktok.com/@user/video/1234567890"
```

下载抖音 `modal_id` 分享页，脚本会自动归一化为标准视频页：

```bash
scripts/ytdlp_download.sh "https://www.douyin.com/user/self?modal_id=7639305281563254986"
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

## 质量预设

| 预设 | 用途 | 行为 |
| --- | --- | --- |
| `compatible` | 默认下载 | MP4/H.264/AAC 或 M4A 优先，最高 1080p |
| `best` | 最高质量收藏 | 使用源站最高质量，可能输出 WebM/MKV/AV1/VP9 |
| `mobile` | 手机、微信、QuickTime | 720p MP4 兼容文件 |
| `small` | 快速测试、省空间 | 360p 或 480p，小文件 |
| `raw` | 专家模式 | 尽量不干预 `yt-dlp` 默认格式选择 |

`--quality HEIGHT` 表示最高高度，会在 preset 的兼容策略内调整上限。`--format FORMAT` 是专家覆盖项，优先级最高。

## 平台策略

| 平台 | 策略 |
| --- | --- |
| YouTube | 默认 `compatible`；最高画质用 `best`；注意 JS runtime 警告 |
| TikTok | 默认走平台原格式，不强制高度筛选；显式 preset 时才套用质量策略 |
| Vimeo | 默认 `compatible`，下载后验证 HLS 合并结果 |
| Bilibili | 公开视频可下；高清或会员内容需要用户授权 cookies |
| Twitter/X | 公开视频可下；登录、年龄限制或删除内容给出明确原因 |
| Twitch Clip | 默认支持 clip；直播和 VOD 需用户明确要求 |
| Archive.org | Archive.org 集合页可能包含多个媒体文件，先 `--list-formats` 或明确 `--playlist` |
| 抖音 | 当前不纳入可靠下载承诺，原因是官方 `yt-dlp` 抖音 extractor 缺少稳定 `a_bogus` 签名能力 |

## 下载后验证

下载后验证默认开启。脚本会使用 `ffprobe` 检查输出文件是否包含视频流、容器是否符合兼容预设、编码和时长是否可读。

跳过验证：

```bash
scripts/ytdlp_download.sh --no-verify "VIDEO_URL"
```

## 安全设计

- 脚本使用 bash 数组执行命令，不使用 `eval`。
- OpenCode 中优先调用 `~/.config/opencode/skills/yt-dlp-downloader/scripts/ytdlp_download.sh`，不要优先裸跑 `yt-dlp`。
- URL 只接受 `http://` 和 `https://`。
- 默认添加 `--no-playlist`，避免误下载整个播放列表。
- Archive.org 集合页不会默认批量下载，必须先确认格式或显式允许播放列表。
- 浏览器 cookies 只在显式传入 `--cookies-browser` 时使用。
- 支持的 cookies 浏览器为 `chrome`、`firefox`、`safari`、`edge`、`brave`、`opera`。
- 抖音返回需要 `fresh cookies` 时，仍需先获得用户授权，再用 `--cookies-browser` 重试；如默认 profile 无效，可指定实际使用的 profile，例如 `--cookies-browser chrome:Default`。
- 若日志显示 cookies 已成功提取但仍报 `fresh cookies`，这通常不是本脚本的 cookies 读取问题，而是 `yt-dlp` 上游抖音 extractor 缺少抖音接口每次请求生成的 `a_bogus` 等签名参数。
- 不要照搬第三方抖音 `a_bogus` / 签名实现到本技能；`yt-dlp` 上游相关 PR 已出现来源和许可证争议。本技能只做安全封装和清晰提示，不内置绕过性签名算法。
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
