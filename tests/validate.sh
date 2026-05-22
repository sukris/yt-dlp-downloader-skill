#!/usr/bin/env bash
set -Eeuo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
skill_file="$repo_dir/SKILL.md"
script_file="$repo_dir/scripts/ytdlp_download.sh"
readme_file="$repo_dir/README.md"

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

assert_fails_with() {
  local expected="$1"
  shift
  local output
  if output="$("$@" 2>&1)"; then
    fail "command should fail: $*"
  fi
  printf '%s' "$output" | grep -q "$expected" || fail "expected error containing '$expected' from: $*"
}

[[ -f "$skill_file" ]] || fail "missing SKILL.md"
[[ -f "$script_file" ]] || fail "missing ytdlp_download.sh"
[[ -f "$readme_file" ]] || fail "missing README.md"

grep -q '^---$' "$skill_file" || fail "SKILL.md missing frontmatter delimiter"
grep -q '^name: yt-dlp-downloader$' "$skill_file" || fail "SKILL.md name mismatch"
grep -q '^description: Use when' "$skill_file" || fail "description must start with Use when"
grep -q 'yt-dlp' "$skill_file" || fail "SKILL.md missing yt-dlp keyword"
grep -q 'TikTok' "$skill_file" || fail "SKILL.md missing TikTok keyword"
grep -q '抖音' "$skill_file" || fail "SKILL.md missing Douyin keyword"
grep -q '默认不读取浏览器 cookies' "$skill_file" || fail "SKILL.md missing cookie safety rule"
grep -q 'fresh cookies' "$skill_file" || fail "SKILL.md should mention fresh cookies failures"
grep -q '\${CLAUDE_SKILL_DIR}/scripts/ytdlp_download.sh' "$skill_file" || fail "SKILL.md should reference CLAUDE_SKILL_DIR"
grep -q '~/.config/opencode/skills/yt-dlp-downloader/scripts/ytdlp_download.sh' "$skill_file" || fail "SKILL.md should reference OpenCode script path"
grep -q '不要优先直接运行裸 `yt-dlp`' "$skill_file" || fail "SKILL.md should forbid preferring bare yt-dlp"
grep -q 'fresh cookies' "$readme_file" || fail "README.md should mention fresh cookies failures"

grep -q 'eval ' "$script_file" && fail "script must not use eval"
grep -q 'cmd=(' "$script_file" || fail "script must build command with arrays"
grep -q 'validate_url' "$script_file" || fail "script missing URL validation"
grep -q 'validate_browser' "$script_file" || fail "script missing browser validation"
grep -q 'validate_quality' "$script_file" || fail "script missing quality validation"
grep -q 'normalize_url' "$script_file" || fail "script missing URL normalization"

bash -n "$script_file"

help_output="$($script_file --help)"
printf '%s' "$help_output" | grep -q 'yt-dlp 安全下载封装' || fail "help output missing title"

dry_run_output="$($script_file --dry-run "https://www.tiktok.com/@example/video/1234567890123456789")"
printf '%s' "$dry_run_output" | grep -F -q -- '--no-playlist' || fail "dry-run should include --no-playlist by default"

douyin_modal_output="$($script_file --dry-run "https://www.douyin.com/user/self?from_tab_name=main&modal_id=7639305281563254986&showSubTab=video&showTab=record")"
printf '%s' "$douyin_modal_output" | grep -F -q 'https://www.douyin.com/video/7639305281563254986' || fail "Douyin modal_id URL should normalize to video URL"

playlist_output="$($script_file --dry-run --playlist "https://www.tiktok.com/@example/video/1234567890123456789")"
if printf '%s' "$playlist_output" | grep -F -q -- '--no-playlist'; then
  fail "playlist mode should not include --no-playlist"
fi

quality_output="$($script_file --dry-run --quality 720 "https://example.com/video")"
printf '%s' "$quality_output" | grep -F -q 'height\<=720' || fail "quality dry-run should include height selector"

audio_output="$($script_file --dry-run --audio "https://example.com/video")"
printf '%s' "$audio_output" | grep -F -q -- '--audio-format mp3' || fail "audio dry-run should include mp3 extraction"

cookie_profile_output="$($script_file --dry-run --cookies-browser chrome:Default "https://example.com/video")"
printf '%s' "$cookie_profile_output" | grep -F -q -- '--cookies-from-browser chrome:Default' || fail "cookies browser should allow explicit profile"

assert_fails_with '不支持的浏览器' "$script_file" --dry-run --cookies-browser netscape "https://example.com/video"
assert_fails_with '只支持 http/https URL' "$script_file" --dry-run "file:///tmp/video.mp4"
assert_fails_with '必须是数字' "$script_file" --dry-run --quality 720p "https://example.com/video"

printf 'PASS: yt-dlp skill validation passed\n'
