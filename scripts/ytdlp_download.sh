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
  -q, --quality HEIGHT       限制最高画质，如 720、1080
  -f, --format FORMAT        指定 yt-dlp 格式选择器或格式 ID
  -l, --list-formats         只列出可用格式，不下载
      --thumbnail            下载缩略图
      --metadata             写出 info JSON
      --cookies-browser SPEC 使用浏览器 cookies：chrome/firefox/safari/edge/brave/opera，可带 :PROFILE
      --playlist             允许下载播放列表
      --playlist-range RANGE 下载播放列表范围，如 1:5；会自动允许播放列表
      --proxy URL            使用代理，支持 http/https/socks4/socks5/socks5h
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

validate_quality() {
  local quality="$1"
  [[ "$quality" =~ ^[0-9]+$ ]] || fail "--quality 必须是数字，如 720 或 1080"
  (( quality > 0 )) || fail "--quality 必须大于 0"
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
        urls+=("$(normalize_url "$1")")
        shift
      done
      ;;
    -*)
      fail "未知选项: $1"
      ;;
    *)
      validate_url "$1"
      urls+=("$(normalize_url "$1")")
      shift
      ;;
  esac
done

(( ${#urls[@]} > 0 )) || fail "缺少 URL。运行 --help 查看用法。"

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
  elif [[ -n "$quality" ]]; then
    cmd+=(-f "bestvideo[height<=${quality}]+bestaudio/best[height<=${quality}]")
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
  exit 0
fi

mkdir -p "$download_path"
"${cmd[@]}"

printf '\n完成，文件已保存到: %s\n' "$download_path"
