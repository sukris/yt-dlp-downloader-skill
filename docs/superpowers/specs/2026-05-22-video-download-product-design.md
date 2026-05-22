# 视频下载产品化设计

> 日期：2026-05-22

## 目标

把当前 `yt-dlp` 封装脚本升级为面向用户的视频下载技能。用户给出受支持的公开视频链接后，默认结果应该是一个清晰、可播放、兼容常见播放器的单视频文件，而不只是命令退出码为 0。

## 产品承诺

默认行为必须优先满足普通用户的预期：

- 默认只下载一个视频，避免误下播放列表或集合。
- 优先生成常见播放器可打开的文件：MP4 容器、H.264 视频、AAC 或 M4A 音频。
- 优先清晰度而不是极小测试文件：普通下载默认最高目标 1080p。
- 保留专家能力：用户明确要求时仍可选择最高质量或指定格式。
- 平台限制、权限问题和失败原因必须用可执行的语言解释。
- 不绕过访问控制、付费内容、私有内容或 cookies 授权。

## 非目标

- 在官方 `yt-dlp` 抖音 extractor 缺少稳定签名能力时，不承诺可靠下载抖音。
- 不自动读取浏览器 cookies。
- 不自动安装工具、不执行 `sudo`、不增加外部 fallback 依赖。
- 不用模糊成功信息掩盖 `yt-dlp` 的真实失败。
- 不把所有平台强行套进同一套格式选择器；部分平台适合使用其原生默认格式。

## 用户意图

| 用户意图 | 用户可能说法 | 产品行为 |
| --- | --- | --- |
| 普通下载 | 下载这个视频 | 使用 `compatible` 预设并验证结果 |
| 高清下载 | 下载高清版 | 目标 1080p 兼容输出，失败时回退并说明 |
| 最高质量 | 下载最高画质收藏 | 使用 `best` 预设，允许 WebM、MKV、VP9、AV1 |
| 手机或分享 | 下载个手机能看的 | 使用 `mobile` 预设，720p MP4 兼容输出 |
| 快速测试 | 先试试看能不能下 | 使用 `small` 预设，360p 或 480p 小文件 |
| 仅音频 | 提取 MP3 | 使用音频模式，默认 MP3 |
| 字幕 | 下载字幕 | 使用字幕参数并支持语言选择 |
| 精确格式 | 用这个格式 ID | 让 `--format` 覆盖产品预设 |
| 需要登录 | 这个要登录 | 先解释原因，用户明确授权后才读取 cookies |

## 质量预设

脚本应该暴露产品语义级别的 `--preset`。普通用户不应该理解复杂的 `yt-dlp` 格式选择语法。

| 预设 | 使用场景 | 目标 | 格式策略 |
| --- | --- | --- | --- |
| `compatible` | 默认 | 清晰、可播放的单文件 | MP4/H.264/AAC 或 M4A，最高 1080p |
| `best` | 收藏级最高质量 | 源站最高质量 | `yt-dlp` 的 bestvideo+bestaudio，可能输出 WebM/MKV/AV1/VP9 |
| `mobile` | 手机、聊天软件、QuickTime | 720p 兼容文件 | MP4/H.264/AAC 或 M4A，最高 720p |
| `small` | 烟测、低带宽 | 小而可播放 | 360p 或 480p，MP4 优先 |
| `raw` | 专家模式 | 最少产品干预 | 尊重用户指定格式或 `yt-dlp` 原生默认 |

默认命令：

```bash
scripts/ytdlp_download.sh "URL"
```

等价产品意图：

```bash
scripts/ytdlp_download.sh --preset compatible "URL"
```

## 格式选择规则

脚本应该在一个地方把预设映射为格式选择器。

`compatible` 目标：

```text
bestvideo[height<=1080][ext=mp4][vcodec^=avc1]+bestaudio[ext=m4a]/bestvideo[height<=1080][ext=mp4]+bestaudio[ext=m4a]/best[height<=1080][ext=mp4]/bestvideo[height<=1080]+bestaudio/best[height<=1080]
```

`best` 目标：

```text
bestvideo*+bestaudio/best
```

`mobile` 目标：

```text
bestvideo[height<=720][ext=mp4][vcodec^=avc1]+bestaudio[ext=m4a]/bestvideo[height<=720][ext=mp4]+bestaudio[ext=m4a]/best[height<=720][ext=mp4]/best[height<=720]
```

`small` 目标：

```text
bestvideo[height<=480][ext=mp4][vcodec^=avc1]+bestaudio[ext=m4a]/bestvideo[height<=480][ext=mp4]+bestaudio[ext=m4a]/best[height<=480][ext=mp4]/best[height<=360]
```

`raw` 目标：

```text
除非用户提供 --format，否则不添加产品格式选择器。
```

`--quality HEIGHT` 继续保留，但语义是最高高度。它应该调整预设的高度上限，同时保留兼容性偏好。若用户提供 `--format`，则 `--format` 优先级高于 `--preset` 和 `--quality`。

## 平台策略

| 平台 | 可靠范围 | 默认行为 | 特殊处理 |
| --- | --- | --- | --- |
| YouTube | 公开视频 | `compatible`，最高 1080p | 若 `yt-dlp` 提示缺少 JS runtime，要给出警告；最高质量可能输出 WebM/MKV |
| TikTok | 公开视频，受地区影响 | 用户未显式选择预设时使用原生默认 | 默认不要强制高度筛选，部分视频严格限高会失败 |
| Vimeo | 公开视频 | `compatible` | HLS 下载后必须验证合并结果 |
| Bilibili | 公开低清或标准清晰度 | `compatible` | 更高清晰度可能需要 cookies 或会员，读取 cookies 前必须询问 |
| Twitter/X | 公开视频 | `compatible` 或平台提供的 MP4 | 很多视频需要登录、年龄验证或已删除，需要清晰分类 |
| Twitch Clip | 公开 clips | 兼容或原生 clip 下载 | 除非用户明确要求，不默认下载直播或大型 VOD |
| Archive.org | 明确媒体文件 | 集合页先列格式或要求确认 | `/details/` 页面即使有 no-playlist 也可能下载多个文件 |
| 抖音 | 仅诊断 | 不纳入可靠下载承诺 | 不反复尝试 cookies，说明上游 `a_bogus` 签名限制 |

## 下载后验证

命令退出码不足以证明文件可用。下载成功后，默认应该验证媒体文件。

验证项：

- 至少创建或更新了一个媒体文件。
- 视频模式输出必须包含视频流。
- 若源媒体包含音频，输出应包含音频流。
- 普通视频时长应大于 3 秒；更短时要报告为源内容很短。
- `compatible`、`mobile`、`small` 预设应优先 MP4 容器、H.264 视频、AAC/M4A 音频。
- 分辨率必须符合预设或 `--quality` 上限。
- 输出文件路径、容器、时长、分辨率、视频编码、音频编码和兼容性结论。

成功输出示例：

```text
下载完成：
文件：example.mp4
时长：00:03:24
分辨率：1920x1080
视频编码：h264
音频编码：aac
兼容性：适合 QuickTime、手机和常见播放器
```

## 错误分类

脚本应保留 `yt-dlp` 原始输出，同时总结常见失败。

| 失败类型 | 用户解释 | 下一步 |
| --- | --- | --- |
| `Requested format is not available` | 当前平台没有请求的清晰度或格式组合 | 自动回退兼容默认值，或运行 `--list-formats` |
| `HTTP 403` | 平台拒绝匿名访问 | 更新 `yt-dlp`，或在确认有权限后授权 cookies |
| 登录要求 | 内容需要登录 | 要求用户明确授权 `--cookies-browser` |
| 抖音 `fresh cookies` | 不是普通 cookies 过期问题 | 说明上游签名限制并停止重试 |
| 缺少 `ffmpeg` | 无法合并音视频或提取音频 | 提示安装 `ffmpeg` |
| 输出无法播放 | 容器或编码不兼容 | 使用 `compatible` 预设或重新封装 MP4 |
| 开始下载多个文件 | 可能是播放列表或集合页 | 停止并要求用户明确确认播放列表 |

## 命令行界面

新增或明确的选项：

```text
--preset compatible|best|mobile|small|raw
--verify
--no-verify
```

保留现有选项：

```text
--quality HEIGHT
--format FORMAT
--list-formats
--audio
--subs
--auto-subs
--sub-langs LANGS
--cookies-browser BROWSER[:PROFILE]
--playlist
--playlist-range RANGE
--proxy URL
--dry-run
```

优先级：

1. `--audio` 切换为音频提取。
2. `--list-formats` 只列格式，不下载、不验证。
3. `--format` 覆盖预设格式选择。
4. `--quality` 作为预设高度上限。
5. `--preset` 选择产品策略。
6. 未指定预设时默认 `compatible`，但 TikTok 等平台可以有平台覆盖策略。

## 设计完整性清单

- 只给 URL 的默认流程有明确行为。
- 质量选择是产品预设，不是裸 `yt-dlp` 选择器。
- 普通下载优先兼容输出。
- 专家仍可用 `--format` 和 `--preset best` 覆盖。
- 平台差异已明确。
- 抖音不纳入可靠下载承诺。
- cookies 仅在用户授权后使用。
- 播放列表和集合下载仅在用户明确要求后使用。
- 使用 `ffprobe` 验证下载文件，而不是只看退出码。
- 常见失败有可执行的摘要。

## 验收矩阵

实现后必须通过以下检查：

| 平台 | 测试 | 期望 |
| --- | --- | --- |
| YouTube | 正常公开视频，默认预设 | MP4 兼容输出，时长 > 3 秒，有视频和音频流 |
| TikTok | 已知公开视频，默认行为 | 不使用严格高度筛选也能下载 |
| Vimeo | 正常公开视频 | 视频和音频合并后通过验证 |
| Bilibili | 公开视频 | 可下载公开清晰度，或清楚说明登录要求 |
| Twitter/X | 公开视频 | 下载可播放 MP4，或清楚说明登录/删除原因 |
| Twitch Clip | 公开 clip | 下载 clip，不误下直播或 VOD |
| Archive.org | 集合 URL | 未明确 playlist 时不静默批量下载 |
| 抖音 | 短链 URL | 输出不支持诊断，不进入反复 cookies 尝试 |
