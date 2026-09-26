#!/bin/sh
# codesign wrapper: strip Google Drive / Finder xattrs immediately before signing.
# Real codesign is invoked afterward. Used only during Swan Match iOS archive builds.
set -e

LOG_DIR="${HOME}/Library/Caches/SwanMatchFlutterBuild"
mkdir -p "${LOG_DIR}"
DEBUG_LOG="${LOG_DIR}/debug-codesign-wrap.log"

# #region agent log
# Also mirror into project debug log when available
PROJECT_DEBUG=""
for candidate in \
  "/Users/apple/Library/CloudStorage/GoogleDrive-harirajanncse@gmail.com/My Drive/Macbook Pro/Swan_Match_app-main/.cursor/debug-c1ab8f.log"
do
  if [ -d "$(dirname "$candidate")" ]; then
    PROJECT_DEBUG="$candidate"
    break
  fi
done
# #endregion

strip_target() {
  target="$1"
  [ -e "$target" ] || return 0
  xattr -cr "$target" 2>/dev/null || true
  # Remove AppleDouble leftovers if present
  find "$target" -name '._*' -delete 2>/dev/null || true
}

# Strip any path-like arguments before calling real codesign.
for arg in "$@"; do
  case "$arg" in
    -* ) ;;
    * )
      if [ -e "$arg" ]; then
        strip_target "$arg"
        # #region agent log
        ts="$(date +%s)000"
        finder="$(xattr -l "$arg" 2>/dev/null | grep -c 'com.apple.FinderInfo' || true)"
        fpfs="$(xattr -l "$arg" 2>/dev/null | grep -c 'com.apple.fileprovider.fpfs' || true)"
        line=$(printf '{"sessionId":"c1ab8f","runId":"post-fix","hypothesisId":"F","location":"scripts/codesign_wrap.sh","message":"pre-codesign xattr strip","data":{"path":"%s","finderInfoCount":%s,"fileProviderCount":%s},"timestamp":%s}\n' \
          "$arg" "${finder:-0}" "${fpfs:-0}" "$ts")
        echo "$line" >> "${DEBUG_LOG}" 2>/dev/null || true
        if [ -n "$PROJECT_DEBUG" ]; then
          echo "$line" >> "$PROJECT_DEBUG" 2>/dev/null || true
        fi
        # #endregion
      fi
      ;;
  esac
done

exec /usr/bin/codesign "$@"
