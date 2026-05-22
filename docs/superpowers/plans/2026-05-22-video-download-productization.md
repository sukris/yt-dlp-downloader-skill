# 视频下载产品化实施计划

> **给 Agent 执行者：** 必须使用 `superpowers:subagent-driven-development`（推荐）或 `superpowers:executing-plans` 按任务执行。本计划使用复选框语法跟踪进度。

**目标：** 将 `yt-dlp` 下载技能产品化，让默认下载结果成为清晰、可播放、平台感知的单视频文件，并带有下载后验证。

**架构：** 保留当前单个 Bash 封装脚本，在其中增加小而明确的函数：预设校验、平台检测、格式选择、输出发现、`ffprobe` 验证和错误摘要。同步更新 `README.md` 与 `SKILL.md`，确保文档和脚本行为一致。

**技术栈：** Bash、`yt-dlp`、`ffmpeg`/`ffprobe`、现有 `tests/validate.sh` shell 校验，以及实现后的真实平台验收测试。

---

## 文件结构

- 修改 `scripts/ytdlp_download.sh`：增加 `--preset`、`--verify`、`--no-verify`、平台感知格式策略、`ffprobe` 验证、Archive.org 集合页保护、抖音诊断停止和可执行错误摘要。
- 修改 `tests/validate.sh`：增加预设 dry-run 测试、优先级测试、平台覆盖测试、Archive.org 保护测试、抖音诊断行为测试和验证参数解析测试。
- 修改 `SKILL.md`：记录产品默认行为、质量预设、平台策略、验证输出和抖音不支持状态。
- 修改 `README.md`：记录安装假设、使用示例、平台矩阵、质量策略和故障排查。
- 保留 `docs/superpowers/specs/2026-05-22-video-download-product-design.md` 作为产品设计依据。

---

### 任务 1：增加产品预设解析和 dry-run 格式选择器

**文件：**
- 修改：`scripts/ytdlp_download.sh`
- 修改：`tests/validate.sh`

- [ ] **步骤 1：先写失败测试，覆盖预设解析和格式选择器**

在 `tests/validate.sh` 现有 `quality_output` 断言后添加：

```bash
compatible_output="$($script_file --dry-run "https://www.youtube.com/watch?v=aqz-KE-bpKQ")"
printf '%s' "$compatible_output" | grep -F -q 'height\<=1080' || fail "default preset should cap compatible video at 1080p"
printf '%s' "$compatible_output" | grep -F -q 'vcodec^=avc1' || fail "default preset should prefer H.264 video"
printf '%s' "$compatible_output" | grep -F -q 'ext=m4a' || fail "default preset should prefer M4A/AAC audio"

best_output="$($script_file --dry-run --preset best "https://www.youtube.com/watch?v=aqz-KE-bpKQ")"
printf '%s' "$best_output" | grep -F -q 'bestvideo*+bestaudio/best' || fail "best preset should use yt-dlp best selector"

mobile_output="$($script_file --dry-run --preset mobile "https://www.youtube.com/watch?v=aqz-KE-bpKQ")"
printf '%s' "$mobile_output" | grep -F -q 'height\<=720' || fail "mobile preset should cap video at 720p"

small_output="$($script_file --dry-run --preset small "https://www.youtube.com/watch?v=aqz-KE-bpKQ")"
printf '%s' "$small_output" | grep -F -q 'height\<=480' || fail "small preset should prefer 480p-compatible output"

raw_output="$($script_file --dry-run --preset raw "https://www.youtube.com/watch?v=aqz-KE-bpKQ")"
if printf '%s' "$raw_output" | grep -F -q -- ' -f '; then
  fail "raw preset should not add a product format selector"
fi

quality_preset_output="$($script_file --dry-run --preset compatible --quality 720 "https://www.youtube.com/watch?v=aqz-KE-bpKQ")"
printf '%s' "$quality_preset_output" | grep -F -q 'height\<=720' || fail "quality should lower compatible preset height cap"
printf '%s' "$quality_preset_output" | grep -F -q 'vcodec^=avc1' || fail "quality should preserve compatible codec preference"

format_override_output="$($script_file --dry-run --preset compatible --format '18' "https://www.youtube.com/watch?v=aqz-KE-bpKQ")"
printf '%s' "$format_override_output" | grep -F -q -- '-f 18' || fail "explicit --format should override presets"
```

- [ ] **步骤 2：运行测试，确认失败原因正确**

运行：

```bash
tests/validate.sh
```

预期：失败，因为当前脚本还不认识 `--preset`，或默认 `compatible` 选择器尚不存在。

- [ ] **步骤 3：增加预设状态和校验函数**

在 `scripts/ytdlp_download.sh` 的 `validate_quality()` 后添加：

```bash
validate_preset() {
  case "$1" in
    compatible|best|mobile|small|raw) ;;
    *) fail "不支持的预设: $1。可用值: compatible, best, mobile, small, raw" ;;
  esac
}
```

在 `validate_proxy()` 后添加：

```bash
format_for_preset() {
  local selected_preset="$1"
  local max_height="$2"

  case "$selected_preset" in
    compatible)
      printf 'bestvideo[height<=%s][ext=mp4][vcodec^=avc1]+bestaudio[ext=m4a]/bestvideo[height<=%s][ext=mp4]+bestaudio[ext=m4a]/best[height<=%s][ext=mp4]/bestvideo[height<=%s]+bestaudio/best[height<=%s]\n' "$max_height" "$max_height" "$max_height" "$max_height" "$max_height"
      ;;
    best)
      printf 'bestvideo*+bestaudio/best\n'
      ;;
    mobile)
      printf 'bestvideo[height<=%s][ext=mp4][vcodec^=avc1]+bestaudio[ext=m4a]/bestvideo[height<=%s][ext=mp4]+bestaudio[ext=m4a]/best[height<=%s][ext=mp4]/best[height<=%s]\n' "$max_height" "$max_height" "$max_height" "$max_height"
      ;;
    small)
      printf 'bestvideo[height<=%s][ext=mp4][vcodec^=avc1]+bestaudio[ext=m4a]/bestvideo[height<=%s][ext=mp4]+bestaudio[ext=m4a]/best[height<=%s][ext=mp4]/best[height<=360]\n' "$max_height" "$max_height" "$max_height"
      ;;
    raw)
      printf '\n'
      ;;
  esac
}
```

在选项默认值区域添加：

```bash
preset="compatible"
preset_explicit=false
```

在参数解析中、`--thumbnail` 前添加：

```bash
    --preset)
      require_value "$1" "${2-}"
      validate_preset "$2"
      preset="$2"
      preset_explicit=true
      shift 2
      ;;
```

在帮助文本选项中添加：

```text
      --preset PRESET        质量预设：compatible/best/mobile/small/raw，默认 compatible
```

- [ ] **步骤 4：在命令构造中应用预设选择器**

替换当前格式选择块：

```bash
  if [[ -n "$format_selector" ]]; then
    cmd+=(-f "$format_selector")
  elif [[ -n "$quality" ]]; then
    cmd+=(-f "bestvideo[height<=${quality}][ext=mp4]+bestaudio[ext=m4a]/bestvideo[height<=${quality}]+bestaudio/best[height<=${quality}]")
  fi
```

替换为：

```bash
  if [[ -n "$format_selector" ]]; then
    cmd+=(-f "$format_selector")
  else
    case "$preset" in
      compatible)
        preset_height="${quality:-1080}"
        ;;
      mobile)
        preset_height="${quality:-720}"
        ;;
      small)
        preset_height="${quality:-480}"
        ;;
      best|raw)
        preset_height="${quality:-1080}"
        ;;
    esac

    selector="$(format_for_preset "$preset" "$preset_height")"
    if [[ -n "$selector" ]]; then
      cmd+=(-f "$selector")
    fi
  fi
```

- [ ] **步骤 5：运行测试确认通过**

运行：

```bash
bash -n scripts/ytdlp_download.sh
tests/validate.sh
```

预期：两个命令都通过。

---

### 任务 2：增加平台检测和平台默认策略

**文件：**
- 修改：`scripts/ytdlp_download.sh`
- 修改：`tests/validate.sh`

- [ ] **步骤 1：先写失败测试，覆盖平台策略**

在 `tests/validate.sh` 的预设测试后添加：

```bash
tiktok_default_output="$($script_file --dry-run "https://www.tiktok.com/@example/video/1234567890123456789")"
if printf '%s' "$tiktok_default_output" | grep -F -q -- ' -f '; then
  fail "TikTok default should not force product height selector"
fi

tiktok_explicit_preset_output="$($script_file --dry-run --preset mobile "https://www.tiktok.com/@example/video/1234567890123456789")"
printf '%s' "$tiktok_explicit_preset_output" | grep -F -q 'height\<=720' || fail "explicit TikTok mobile preset should apply selector"

archive_guard_output="$($script_file --dry-run "https://archive.org/details/ElephantsDream" 2>&1 || true)"
printf '%s' "$archive_guard_output" | grep -q 'Archive.org 集合页' || fail "Archive.org collection URL should require explicit confirmation"

douyin_guard_output="$($script_file --dry-run "https://v.douyin.com/qEugPTRvc7Q/" 2>&1 || true)"
printf '%s' "$douyin_guard_output" | grep -q '抖音当前不纳入可靠下载' || fail "Douyin should report unsupported diagnostic path"
```

- [ ] **步骤 2：运行测试，确认失败原因正确**

运行：

```bash
tests/validate.sh
```

预期：失败，因为平台策略尚未实现。

- [ ] **步骤 3：增加平台检测函数**

在 `scripts/ytdlp_download.sh` 的 `normalize_url()` 后添加：

```bash
detect_platform() {
  local url="$1"
  case "$url" in
    *://www.youtube.com/*|*://youtube.com/*|*://youtu.be/*) printf 'youtube\n' ;;
    *://www.tiktok.com/*|*://tiktok.com/*) printf 'tiktok\n' ;;
    *://v.douyin.com/*|*://www.douyin.com/*|*://douyin.com/*) printf 'douyin\n' ;;
    *://archive.org/details/*) printf 'archive_details\n' ;;
    *://www.bilibili.com/*|*://bilibili.com/*) printf 'bilibili\n' ;;
    *://x.com/*|*://twitter.com/*) printf 'twitter\n' ;;
    *://clips.twitch.tv/*|*://www.twitch.tv/*) printf 'twitch\n' ;;
    *://vimeo.com/*) printf 'vimeo\n' ;;
    *) printf 'generic\n' ;;
  esac
}

has_single_platform() {
  local expected="$1"
  local url
  for url in "${urls[@]}"; do
    [[ "$(detect_platform "$url")" == "$expected" ]] || return 1
  done
  return 0
}
```

- [ ] **步骤 4：在命令构造前增加平台保护**

在缺少 URL 检查后：

```bash
(( ${#urls[@]} > 0 )) || fail "缺少 URL。运行 --help 查看用法。"
```

添加：

```bash
if has_single_platform douyin; then
  fail "抖音当前不纳入可靠下载。官方 yt-dlp 抖音 extractor 常因 a_bogus 签名缺失报 fresh cookies，建议暂时使用浏览器观看或等待上游修复。"
fi

if has_single_platform archive_details && [[ "$allow_playlist" != true && "$list_formats" != true ]]; then
  fail "Archive.org 集合页可能包含多个媒体文件。请先使用 --list-formats 查看，或明确传 --playlist/--playlist-range。"
fi

if has_single_platform tiktok && [[ "$preset_explicit" != true && -z "$quality" && -z "$format_selector" ]]; then
  preset="raw"
fi
```

- [ ] **步骤 5：运行测试确认通过**

运行：

```bash
bash -n scripts/ytdlp_download.sh
tests/validate.sh
```

预期：两个命令都通过。

---

### 任务 3：增加验证参数和 `ffprobe` 下载后验证

**文件：**
- 修改：`scripts/ytdlp_download.sh`
- 修改：`tests/validate.sh`

- [ ] **步骤 1：先写失败测试，覆盖验证参数**

在 `tests/validate.sh` 的选项解析测试附近添加：

```bash
verify_output="$($script_file --dry-run --verify "https://www.youtube.com/watch?v=aqz-KE-bpKQ")"
printf '%s' "$verify_output" | grep -q '下载后验证: 开启' || fail "--verify should report enabled verification"

no_verify_output="$($script_file --dry-run --no-verify "https://www.youtube.com/watch?v=aqz-KE-bpKQ")"
printf '%s' "$no_verify_output" | grep -q '下载后验证: 关闭' || fail "--no-verify should report disabled verification"
```

- [ ] **步骤 2：运行测试，确认失败原因正确**

运行：

```bash
tests/validate.sh
```

预期：失败，因为验证参数尚未实现。

- [ ] **步骤 3：增加验证参数状态和解析**

在 `scripts/ytdlp_download.sh` 的选项默认值区域添加：

```bash
verify_download=true
```

在参数解析中、`--dry-run` 前添加：

```bash
    --verify)
      verify_download=true
      shift
      ;;
    --no-verify)
      verify_download=false
      shift
      ;;
```

在帮助文本中添加：

```text
      --verify               下载后用 ffprobe 验证媒体，默认开启
      --no-verify            跳过下载后验证
```

在打印保存路径后添加：

```bash
if [[ "$list_formats" == true || "$dry_run" == true ]]; then
  printf '下载后验证: 关闭\n'
elif [[ "$verify_download" == true ]]; then
  printf '下载后验证: 开启\n'
else
  printf '下载后验证: 关闭\n'
fi
```

- [ ] **步骤 4：增加输出快照和验证函数**

在命令构造前添加：

```bash
snapshot_media_files() {
  local dir="$1"
  if [[ -d "$dir" ]]; then
    find "$dir" -maxdepth 1 -type f \( -name '*.mp4' -o -name '*.mkv' -o -name '*.webm' -o -name '*.mov' -o -name '*.m4a' -o -name '*.mp3' -o -name '*.opus' \) -print 2>/dev/null | sort
  fi
}

verify_media_file() {
  local file="$1"

  command -v ffprobe >/dev/null 2>&1 || fail "下载后验证需要 ffprobe。请安装 ffmpeg，或使用 --no-verify 跳过验证。"

  local probe_output
  probe_output="$(ffprobe -v error -show_entries format=duration,format_name -show_entries stream=codec_type,codec_name,width,height -of default=noprint_wrappers=1 "$file")"

  printf '\n验证结果:\n'
  printf '文件: %s\n' "$file"
  printf '%s\n' "$probe_output"

  printf '%s\n' "$probe_output" | grep -q 'codec_type=video' || fail "验证失败: 输出文件没有视频流: $file"

  if [[ "$preset" == compatible || "$preset" == mobile || "$preset" == small ]]; then
    printf '%s\n' "$probe_output" | grep -q 'format_name=.*mp4\|format_name=.*mov' || fail "验证失败: 兼容预设应优先输出 MP4/MOV 兼容容器: $file"
  fi
}

verify_downloaded_media() {
  local before_file="$1"
  local after_file="$2"
  local file

  while IFS= read -r file; do
    if ! grep -Fxq "$file" "$before_file"; then
      verify_media_file "$file"
      return
    fi
  done < "$after_file"

  fail "验证失败: 未找到新的媒体文件。"
}
```

- [ ] **步骤 5：捕获下载前后文件并执行验证**

替换底部执行块：

```bash
mkdir -p "$download_path"
"${cmd[@]}"

printf '\n完成，文件已保存到: %s\n' "$download_path"
```

替换为：

```bash
mkdir -p "$download_path"
before_snapshot="$(mktemp)"
after_snapshot="$(mktemp)"
trap 'rm -f "$before_snapshot" "$after_snapshot"' EXIT
snapshot_media_files "$download_path" >"$before_snapshot"

"${cmd[@]}"

snapshot_media_files "$download_path" >"$after_snapshot"

if [[ "$verify_download" == true && "$list_formats" != true ]]; then
  verify_downloaded_media "$before_snapshot" "$after_snapshot"
fi

printf '\n完成，文件已保存到: %s\n' "$download_path"
```

- [ ] **步骤 6：运行测试确认通过**

运行：

```bash
bash -n scripts/ytdlp_download.sh
tests/validate.sh
```

预期：两个命令都通过。

---

### 任务 4：增加错误摘要，但保留 `yt-dlp` 原始输出

**文件：**
- 修改：`scripts/ytdlp_download.sh`
- 修改：`tests/validate.sh`

- [ ] **步骤 1：先写失败测试，覆盖错误分类文案**

在 `tests/validate.sh` 的脚本结构检查后添加：

```bash
grep -q 'summarize_failure' "$script_file" || fail "script should classify common yt-dlp failures"
grep -q 'Requested format is not available' "$script_file" || fail "script should classify unavailable format errors"
grep -q 'HTTP Error 403' "$script_file" || fail "script should classify 403 errors"
grep -q 'ffmpeg' "$script_file" || fail "script should classify ffmpeg errors"
```

- [ ] **步骤 2：运行测试，确认失败原因正确**

运行：

```bash
tests/validate.sh
```

预期：失败，因为 `summarize_failure` 尚未实现。

- [ ] **步骤 3：增加失败摘要函数**

在命令构造前添加：

```bash
summarize_failure() {
  local log_file="$1"

  if grep -q 'Requested format is not available' "$log_file"; then
    printf '\n失败原因: 当前平台没有请求的清晰度或格式组合。\n' >&2
    printf '下一步: 去掉 --quality/--format 使用默认 compatible，或先运行 --list-formats 选择可用格式。\n' >&2
  elif grep -q 'HTTP Error 403\|Forbidden' "$log_file"; then
    printf '\n失败原因: 平台拒绝匿名访问或当前网络访问受限。\n' >&2
    printf '下一步: 先更新 yt-dlp；如果你确认有权限，再明确授权 --cookies-browser。\n' >&2
  elif grep -qi 'login required\|sign in\|cookies' "$log_file"; then
    printf '\n失败原因: 该内容可能需要登录态。\n' >&2
    printf '下一步: 如果你确认有权限，可以明确授权 --cookies-browser chrome:Default。\n' >&2
  elif grep -qi 'ffmpeg' "$log_file"; then
    printf '\n失败原因: 音视频合并或音频提取需要 ffmpeg。\n' >&2
    printf '下一步: 安装 ffmpeg，或使用 --no-verify 仅跳过验证。\n' >&2
  else
    printf '\n失败原因: yt-dlp 下载失败，以上保留了原始错误。\n' >&2
    printf '下一步: 可先运行 --list-formats 检查该 URL 是否可解析。\n' >&2
  fi
}
```

- [ ] **步骤 4：捕获 `yt-dlp` 失败并调用摘要函数**

替换直接执行命令的行：

```bash
"${cmd[@]}"
```

替换为：

```bash
download_log="$(mktemp)"
trap 'rm -f "$before_snapshot" "$after_snapshot" "$download_log"' EXIT

if ! "${cmd[@]}" 2> >(tee "$download_log" >&2); then
  summarize_failure "$download_log"
  exit 1
fi
```

确保最终只有一个 `trap`，并且包含全部临时文件。

- [ ] **步骤 5：运行测试确认通过**

运行：

```bash
bash -n scripts/ytdlp_download.sh
tests/validate.sh
```

预期：两个命令都通过。

---

### 任务 5：更新技能和 README 文档

**文件：**
- 修改：`SKILL.md`
- 修改：`README.md`
- 修改：`tests/validate.sh`

- [ ] **步骤 1：先写失败文档检查**

在 `tests/validate.sh` 现有文档检查附近添加：

```bash
grep -q 'compatible' "$skill_file" || fail "SKILL.md should document compatible preset"
grep -q 'mobile' "$skill_file" || fail "SKILL.md should document mobile preset"
grep -q '下载后验证' "$skill_file" || fail "SKILL.md should document post-download verification"
grep -q '平台策略' "$skill_file" || fail "SKILL.md should document platform strategies"
grep -q 'compatible' "$readme_file" || fail "README.md should document compatible preset"
grep -q '下载后验证' "$readme_file" || fail "README.md should document post-download verification"
grep -q 'Archive.org 集合页' "$readme_file" || fail "README.md should document Archive.org collection risk"
```

- [ ] **步骤 2：运行测试，确认失败原因正确**

运行：

```bash
tests/validate.sh
```

预期：文档更新前失败。

- [ ] **步骤 3：更新 `SKILL.md` 产品行为说明**

增加或改写相关章节，使 `SKILL.md` 明确包含：

```markdown
## 默认产品策略

- 用户只说下载视频时，默认使用 `--preset compatible`。
- compatible 的目标是单个 MP4 兼容文件，优先 H.264 视频和 AAC/M4A 音频，最高 1080p。
- 用户明确要求最高画质时使用 `--preset best`。
- 用户要求手机、微信、QuickTime 可播放时使用 `--preset mobile`。
- 用户要求快速测试或小文件时使用 `--preset small`。
- 下载后验证默认开启，脚本会用 ffprobe 检查媒体流、容器、编码和时长。

## 平台策略

| 平台 | 策略 |
|------|------|
| YouTube | 默认 compatible；最高画质用 best；注意 JS runtime 警告 |
| TikTok | 默认走平台原格式，不强制高度筛选 |
| Vimeo | 默认 compatible，下载后验证 HLS 合并结果 |
| Bilibili | 公开视频可下；高清或会员内容需要用户授权 cookies |
| Twitter/X | 公开视频可下；登录/年龄/删除内容给出明确原因 |
| Twitch Clip | 默认支持 clip；直播和 VOD 需用户明确要求 |
| Archive.org | 集合页先 list-formats 或要求用户确认 playlist |
| 抖音 | 当前不纳入可靠下载承诺，说明 a_bogus 上游限制 |
```

- [ ] **步骤 4：更新 `README.md` 使用示例**

增加示例：

````markdown
默认兼容下载：

```bash
scripts/ytdlp_download.sh "VIDEO_URL"
```

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
````

同时记录 Archive.org 集合页风险、抖音不支持状态和验证输出。

- [ ] **步骤 5：运行测试确认通过**

运行：

```bash
tests/validate.sh
```

预期：通过。

---

### 任务 6：真实平台验收测试

**文件：**
- 无代码变更；除非测试暴露 bug。

- [ ] **步骤 1：准备干净测试目录**

运行：

```bash
mkdir -p "/var/folders/t1/ry0lljqj313dnmzswn3mwzmr0000gn/T/opencode/ytdlp-acceptance-productized"
```

预期：命令退出码为 0。

- [ ] **步骤 2：测试 YouTube 正常视频默认预设**

运行：

```bash
scripts/ytdlp_download.sh --path "/var/folders/t1/ry0lljqj313dnmzswn3mwzmr0000gn/T/opencode/ytdlp-acceptance-productized/youtube" "https://www.youtube.com/watch?v=aqz-KE-bpKQ"
```

预期：输出 MP4 兼容文件，时长大于 3 秒，有视频流和音频流。

- [ ] **步骤 3：测试 TikTok 默认原生策略**

运行：

```bash
scripts/ytdlp_download.sh --path "/var/folders/t1/ry0lljqj313dnmzswn3mwzmr0000gn/T/opencode/ytdlp-acceptance-productized/tiktok" "https://www.tiktok.com/@stephcn_/video/7622263851152706848?is_from_webapp=1&sender_device=pc"
```

预期：不出现 `Requested format is not available`，验证能找到视频流。

- [ ] **步骤 4：测试 Vimeo 默认策略**

运行：

```bash
scripts/ytdlp_download.sh --path "/var/folders/t1/ry0lljqj313dnmzswn3mwzmr0000gn/T/opencode/ytdlp-acceptance-productized/vimeo" "https://vimeo.com/76979871"
```

预期：验证有视频流和音频流。

- [ ] **步骤 5：测试 Bilibili 公开视频**

运行：

```bash
scripts/ytdlp_download.sh --path "/var/folders/t1/ry0lljqj313dnmzswn3mwzmr0000gn/T/opencode/ytdlp-acceptance-productized/bilibili" "https://www.bilibili.com/video/BV13x41117TL"
```

预期：公开视频质量可下载；若受限制，输出面向用户的登录或 cookies 说明。

- [ ] **步骤 6：测试 Twitter/X 公开视频**

运行：

```bash
scripts/ytdlp_download.sh --path "/var/folders/t1/ry0lljqj313dnmzswn3mwzmr0000gn/T/opencode/ytdlp-acceptance-productized/twitter" --format "http-288" "https://x.com/historyinmemes/status/1790637656616943991"
```

预期：下载可播放 MP4，并输出验证结果。

- [ ] **步骤 7：测试 Twitch clip**

运行：

```bash
scripts/ytdlp_download.sh --path "/var/folders/t1/ry0lljqj313dnmzswn3mwzmr0000gn/T/opencode/ytdlp-acceptance-productized/twitch" "https://clips.twitch.tv/FaintLightGullWholeWheat"
```

预期：下载 clip，并输出验证结果。

- [ ] **步骤 8：测试 Archive.org 集合页保护**

运行：

```bash
scripts/ytdlp_download.sh --path "/var/folders/t1/ry0lljqj313dnmzswn3mwzmr0000gn/T/opencode/ytdlp-acceptance-productized/archive" "https://archive.org/details/ElephantsDream"
```

预期：下载前失败，并输出 Archive.org 集合页说明。

- [ ] **步骤 9：测试抖音诊断**

运行：

```bash
scripts/ytdlp_download.sh "https://v.douyin.com/qEugPTRvc7Q/"
```

预期：下载前失败，并输出抖音不支持说明。

- [ ] **步骤 10：同步安装目录并验证**

运行：

```bash
rtk rsync -a --delete --exclude '.git/' ./ "/Users/kris/.config/opencode/skills/yt-dlp-downloader/"
"/Users/kris/.config/opencode/skills/yt-dlp-downloader/tests/validate.sh"
```

预期：输出 `PASS: yt-dlp skill validation passed`。

---

## 自查

规格覆盖：

- 预设由任务 1 实现。
- 平台策略由任务 2 实现。
- 下载后验证由任务 3 实现。
- 错误分类由任务 4 实现。
- 文档更新由任务 5 实现。
- 真实平台验收由任务 6 覆盖。

占位符检查：

- 计划中没有未解决占位内容。
- 每个任务都有明确文件、代码块、命令和预期结果。

命名一致性：

- `preset`、`preset_explicit`、`verify_download`、`format_for_preset`、`detect_platform`、`has_single_platform`、`snapshot_media_files`、`verify_media_file`、`verify_downloaded_media`、`summarize_failure` 在所有任务中命名一致。
