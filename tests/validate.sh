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
grep -q 'a_bogus' "$skill_file" || fail "SKILL.md should explain Douyin a_bogus failures"
grep -q 'compatible' "$skill_file" || fail "SKILL.md should document compatible preset"
grep -q 'mobile' "$skill_file" || fail "SKILL.md should document mobile preset"
grep -q '下载后验证' "$skill_file" || fail "SKILL.md should document post-download verification"
grep -q '平台策略' "$skill_file" || fail "SKILL.md should document platform strategies"
grep -q '\${CLAUDE_SKILL_DIR}/scripts/ytdlp_download.sh' "$skill_file" || fail "SKILL.md should reference CLAUDE_SKILL_DIR"
grep -q '~/.config/opencode/skills/yt-dlp-downloader/scripts/ytdlp_download.sh' "$skill_file" || fail "SKILL.md should reference OpenCode script path"
grep -q '不要优先直接运行裸 `yt-dlp`' "$skill_file" || fail "SKILL.md should forbid preferring bare yt-dlp"
grep -q 'fresh cookies' "$readme_file" || fail "README.md should mention fresh cookies failures"
grep -q 'a_bogus' "$readme_file" || fail "README.md should explain Douyin a_bogus failures"
grep -q '不要照搬第三方' "$readme_file" || fail "README.md should warn against copying third-party signature code"
grep -q 'compatible' "$readme_file" || fail "README.md should document compatible preset"
grep -q '下载后验证' "$readme_file" || fail "README.md should document post-download verification"
grep -q 'Archive.org 集合页' "$readme_file" || fail "README.md should document Archive.org collection risk"

grep -q 'eval ' "$script_file" && fail "script must not use eval"
grep -q 'cmd=(' "$script_file" || fail "script must build command with arrays"
grep -q 'validate_url' "$script_file" || fail "script missing URL validation"
grep -q 'validate_browser' "$script_file" || fail "script missing browser validation"
grep -q 'validate_quality' "$script_file" || fail "script missing quality validation"
grep -q 'normalize_url' "$script_file" || fail "script missing URL normalization"
grep -q 'summarize_failure' "$script_file" || fail "script should classify common yt-dlp failures"
grep -q 'Requested format is not available' "$script_file" || fail "script should classify unavailable format errors"
grep -q 'HTTP Error 403' "$script_file" || fail "script should classify 403 errors"
grep -q 'ffmpeg' "$script_file" || fail "script should classify ffmpeg errors"

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
printf '%s' "$quality_output" | grep -F -q 'ext=mp4' || fail "quality dry-run should prefer mp4 video for player compatibility"
printf '%s' "$quality_output" | grep -F -q 'ext=m4a' || fail "quality dry-run should prefer m4a audio for player compatibility"

compatible_output="$($script_file --dry-run "https://www.youtube.com/watch?v=aqz-KE-bpKQ")"
printf '%s' "$compatible_output" | grep -F -q 'height\<=1080' || fail "default preset should cap compatible video at 1080p"
printf '%s' "$compatible_output" | grep -F -q 'vcodec\^=avc1' || fail "default preset should prefer H.264 video"
printf '%s' "$compatible_output" | grep -F -q 'ext=m4a' || fail "default preset should prefer M4A/AAC audio"

best_output="$($script_file --dry-run --preset best "https://www.youtube.com/watch?v=aqz-KE-bpKQ")"
printf '%s' "$best_output" | grep -F -q 'bestvideo\*+bestaudio/best' || fail "best preset should use yt-dlp best selector"

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
printf '%s' "$quality_preset_output" | grep -F -q 'vcodec\^=avc1' || fail "quality should preserve compatible codec preference"

format_override_output="$($script_file --dry-run --preset compatible --format '18' "https://www.youtube.com/watch?v=aqz-KE-bpKQ")"
printf '%s' "$format_override_output" | grep -F -q -- '-f 18' || fail "explicit --format should override presets"

tiktok_default_output="$($script_file --dry-run "https://www.tiktok.com/@example/video/1234567890123456789")"
if printf '%s' "$tiktok_default_output" | grep -F -q -- ' -f '; then
  fail "TikTok default should not force product height selector"
fi

tiktok_explicit_preset_output="$($script_file --dry-run --preset mobile "https://www.tiktok.com/@example/video/1234567890123456789")"
printf '%s' "$tiktok_explicit_preset_output" | grep -F -q 'height\<=720' || fail "explicit TikTok mobile preset should apply selector"

verify_output="$($script_file --dry-run --verify "https://www.youtube.com/watch?v=aqz-KE-bpKQ")"
printf '%s' "$verify_output" | grep -q '下载后验证: 开启' || fail "--verify should report enabled verification"

no_verify_output="$($script_file --dry-run --no-verify "https://www.youtube.com/watch?v=aqz-KE-bpKQ")"
printf '%s' "$no_verify_output" | grep -q '下载后验证: 关闭' || fail "--no-verify should report disabled verification"

archive_guard_output="$($script_file --dry-run "https://archive.org/details/ElephantsDream" 2>&1 || true)"
printf '%s' "$archive_guard_output" | grep -q 'Archive.org 集合页' || fail "Archive.org collection URL should require explicit confirmation"

douyin_guard_output="$($script_file --dry-run "https://v.douyin.com/qEugPTRvc7Q/" 2>&1 || true)"
printf '%s' "$douyin_guard_output" | grep -q '抖音当前不纳入可靠下载' || fail "Douyin should report unsupported diagnostic path"

audio_output="$($script_file --dry-run --audio "https://example.com/video")"
printf '%s' "$audio_output" | grep -F -q -- '--audio-format mp3' || fail "audio dry-run should include mp3 extraction"

cookie_profile_output="$($script_file --dry-run --cookies-browser chrome:Default "https://example.com/video")"
printf '%s' "$cookie_profile_output" | grep -F -q -- '--cookies-from-browser chrome:Default' || fail "cookies browser should allow explicit profile"

assert_fails_with '不支持的浏览器' "$script_file" --dry-run --cookies-browser netscape "https://example.com/video"
assert_fails_with '只支持 http/https URL' "$script_file" --dry-run "file:///tmp/video.mp4"
assert_fails_with '必须是数字' "$script_file" --dry-run --quality 720p "https://example.com/video"

printf 'PASS: yt-dlp skill validation passed\n'
