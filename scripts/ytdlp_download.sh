#!/usr/bin/env bash
set -Eeuo pipefail

usage() {
  cat <<'EOF'
yt-dlp 安全下载封装

用法:
  ytdlp_download.sh [选项] URL [URL...]

选项:
  -p, --path DIR             保存目录，默认 ~/Downloads/yt-dlp
  -a, --audio                仅提取音频，默认 mp3
      --audio-format FORMAT  音频格式：best/aac/alac/flac/m4a/mp3/opus/vorbis/wav
  -s, --subs                 下载人工字幕
      --auto-subs            下载自动字幕
      --sub-langs LANGS      字幕语言，默认 all，如 zh-Hans,en
      --preset PRESET        质量预设：compatible/best/mobile/small/raw，默认 compatible
  -q, --quality HEIGHT       限制最高画质，如 720、1080
  -f, --format FORMAT        指定 yt-dlp 格式选择器或格式 ID
  -l, --list-formats         只列出可用格式，不下载
      --thumbnail            下载缩略图
      --metadata             写出 info JSON
      --cookies-browser SPEC 使用浏览器 cookies：chrome/firefox/safari/edge/brave/opera，可带 :PROFILE
      --playlist             允许下载播放列表
      --playlist-range RANGE 下载播放列表范围，如 1:5；会自动允许播放列表
      --proxy URL            使用代理，支持 http/https/socks4/socks5/socks5h
      --verify               下载后用 ffprobe 验证媒体，默认开启
      --no-verify            跳过下载后验证
      --dry-run              打印命令但不执行
  -h, --help                 显示帮助

示例:
  ytdlp_download.sh "https://www.tiktok.com/@user/video/123"
  ytdlp_download.sh --audio "VIDEO_URL"
  ytdlp_download.sh --quality 720 "VIDEO_URL"
EOF
}

fail() {
  printf '错误: %s\n' "$1" >&2
  exit 1
}

require_value() {
  local option="$1"
  local value="${2-}"
  [[ -n "$value" ]] || fail "$option 需要参数值"
  [[ "$value" != -* ]] || fail "$option 需要参数值"
}

validate_url() {
  local url="$1"
  [[ "$url" =~ ^https?:// ]] || fail "只支持 http/https URL: $url"
}

normalize_url() {
  local url="$1"
  local modal_id

  if [[ "$url" =~ ^https?://(www\.)?douyin\.com/user/self\? ]] && [[ "$url" =~ (^|[?&])modal_id=([0-9]+) ]]; then
    modal_id="${BASH_REMATCH[2]}"
    printf 'https://www.douyin.com/video/%s\n' "$modal_id"
    return
  fi

  printf '%s\n' "$url"
}

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

validate_quality() {
  local quality="$1"
  [[ "$quality" =~ ^[0-9]+$ ]] || fail "--quality 必须是数字，如 720 或 1080"
  (( quality > 0 )) || fail "--quality 必须大于 0"
}

validate_preset() {
  case "$1" in
    compatible|best|mobile|small|raw) ;;
    *) fail "不支持的预设: $1。可用值: compatible, best, mobile, small, raw" ;;
  esac
}

validate_audio_format() {
  case "$1" in
    best|aac|alac|flac|m4a|mp3|opus|vorbis|wav) ;;
    *) fail "不支持的音频格式: $1" ;;
  esac
}

validate_browser() {
  local browser_spec="$1"
  local browser_name="${browser_spec%%[:+]*}"

  case "$browser_name" in
    chrome|firefox|safari|edge|brave|opera) ;;
    *) fail "不支持的浏览器: $1。可用值: chrome, firefox, safari, edge, brave, opera，可选格式: chrome:Default" ;;
  esac
}

validate_proxy() {
  local proxy="$1"
  [[ "$proxy" =~ ^(https?|socks4|socks5|socks5h):// ]] || fail "--proxy 需要带协议，如 http://127.0.0.1:8080 或 socks5://127.0.0.1:1080"
}

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

print_command() {
  printf '将执行:'
  printf ' %q' "$@"
  printf '\n'
}

download_path="${HOME}/Downloads/yt-dlp"
audio_only=false
audio_format="mp3"
download_subs=false
download_auto_subs=false
sub_langs="all"
preset="compatible"
preset_explicit=false
quality=""
format_selector=""
list_formats=false
write_thumbnail=false
write_metadata=false
cookies_browser=""
allow_playlist=false
playlist_range=""
proxy=""
dry_run=false
verify_download=true
allow_douyin_modal_dry_run=false
urls=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    -p|--path)
      require_value "$1" "${2-}"
      download_path="$2"
      shift 2
      ;;
    -a|--audio)
      audio_only=true
      shift
      ;;
    --audio-format)
      require_value "$1" "${2-}"
      validate_audio_format "$2"
      audio_format="$2"
      shift 2
      ;;
    -s|--subs)
      download_subs=true
      shift
      ;;
    --auto-subs)
      download_auto_subs=true
      shift
      ;;
    --sub-langs)
      require_value "$1" "${2-}"
      sub_langs="$2"
      shift 2
      ;;
    --preset)
      require_value "$1" "${2-}"
      validate_preset "$2"
      preset="$2"
      preset_explicit=true
      shift 2
      ;;
    -q|--quality)
      require_value "$1" "${2-}"
      validate_quality "$2"
      quality="$2"
      shift 2
      ;;
    -f|--format)
      require_value "$1" "${2-}"
      format_selector="$2"
      shift 2
      ;;
    -l|--list-formats)
      list_formats=true
      shift
      ;;
    --thumbnail)
      write_thumbnail=true
      shift
      ;;
    --metadata)
      write_metadata=true
      shift
      ;;
    --cookies-browser)
      require_value "$1" "${2-}"
      validate_browser "$2"
      cookies_browser="$2"
      shift 2
      ;;
    --playlist)
      allow_playlist=true
      shift
      ;;
    --playlist-range)
      require_value "$1" "${2-}"
      playlist_range="$2"
      allow_playlist=true
      shift 2
      ;;
    --proxy)
      require_value "$1" "${2-}"
      validate_proxy "$2"
      proxy="$2"
      shift 2
      ;;
    --verify)
      verify_download=true
      shift
      ;;
    --no-verify)
      verify_download=false
      shift
      ;;
    --dry-run)
      dry_run=true
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    --)
      shift
      while [[ $# -gt 0 ]]; do
        validate_url "$1"
        if [[ "$1" =~ ^https?://(www\.)?douyin\.com/user/self\? ]] && [[ "$1" =~ (^|[?&])modal_id=([0-9]+) ]]; then
          allow_douyin_modal_dry_run=true
        fi
        urls+=("$(normalize_url "$1")")
        shift
      done
      ;;
    -*)
      fail "未知选项: $1"
      ;;
    *)
      validate_url "$1"
      if [[ "$1" =~ ^https?://(www\.)?douyin\.com/user/self\? ]] && [[ "$1" =~ (^|[?&])modal_id=([0-9]+) ]]; then
        allow_douyin_modal_dry_run=true
      fi
      urls+=("$(normalize_url "$1")")
      shift
      ;;
  esac
done

(( ${#urls[@]} > 0 )) || fail "缺少 URL。运行 --help 查看用法。"

if has_single_platform douyin && [[ !("$dry_run" == true && "$allow_douyin_modal_dry_run" == true) ]]; then
  fail "抖音当前不纳入可靠下载。官方 yt-dlp 抖音 extractor 常因 a_bogus 签名缺失报 fresh cookies，建议暂时使用浏览器观看或等待上游修复。"
fi

if has_single_platform archive_details && [[ "$allow_playlist" != true && "$list_formats" != true ]]; then
  fail "Archive.org 集合页可能包含多个媒体文件。请先使用 --list-formats 查看，或明确传 --playlist/--playlist-range。"
fi

if has_single_platform tiktok && [[ "$preset_explicit" != true && -z "$quality" && -z "$format_selector" ]]; then
  preset="raw"
fi

if [[ "$dry_run" != true ]]; then
  command -v yt-dlp >/dev/null 2>&1 || fail "yt-dlp 未安装。请先按 README 安装依赖后重试。"
  if [[ "$audio_only" == true ]]; then
    command -v ffmpeg >/dev/null 2>&1 || fail "提取音频需要 ffmpeg。macOS 可运行: brew install ffmpeg"
  fi
fi

cmd=(yt-dlp -P "$download_path" --continue)

if [[ "$allow_playlist" == true ]]; then
  if [[ -n "$playlist_range" ]]; then
    cmd+=(--playlist-items "$playlist_range")
  fi
else
  cmd+=(--no-playlist)
fi

if [[ "$list_formats" == true ]]; then
  cmd+=(-F)
else
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

  if [[ "$audio_only" == true ]]; then
    cmd+=(-x --audio-format "$audio_format")
  fi

  if [[ "$download_subs" == true ]]; then
    cmd+=(--write-subs)
  fi

  if [[ "$download_auto_subs" == true ]]; then
    cmd+=(--write-auto-subs)
  fi

  if [[ "$download_subs" == true || "$download_auto_subs" == true ]]; then
    cmd+=(--sub-langs "$sub_langs")
  fi

  if [[ "$write_thumbnail" == true ]]; then
    cmd+=(--write-thumbnail)
  fi

  if [[ "$write_metadata" == true ]]; then
    cmd+=(--write-info-json)
  fi
fi

if [[ -n "$cookies_browser" ]]; then
  cmd+=(--cookies-from-browser "$cookies_browser")
fi

if [[ -n "$proxy" ]]; then
  cmd+=(--proxy "$proxy")
fi

cmd+=("${urls[@]}")

print_command "${cmd[@]}"
printf '保存目录: %s\n' "$download_path"
if [[ "$dry_run" == true ]]; then
  if [[ "$verify_download" == true && "$list_formats" != true ]]; then
    printf '下载后验证: 开启\n'
  else
    printf '下载后验证: 关闭\n'
  fi
elif [[ "$list_formats" == true || "$verify_download" != true ]]; then
  printf '下载后验证: 关闭\n'
else
  printf '下载后验证: 开启\n'
fi

if [[ "$dry_run" == true ]]; then
  exit 0
fi

mkdir -p "$download_path"
before_snapshot="$(mktemp)"
after_snapshot="$(mktemp)"
download_log="$(mktemp)"
trap 'rm -f "$before_snapshot" "$after_snapshot" "$download_log"' EXIT
snapshot_media_files "$download_path" >"$before_snapshot"

if ! "${cmd[@]}" 2> >(tee "$download_log" >&2); then
  summarize_failure "$download_log"
  exit 1
fi

snapshot_media_files "$download_path" >"$after_snapshot"

if [[ "$verify_download" == true && "$list_formats" != true ]]; then
  verify_downloaded_media "$before_snapshot" "$after_snapshot"
fi

printf '\n完成，文件已保存到: %s\n' "$download_path"
