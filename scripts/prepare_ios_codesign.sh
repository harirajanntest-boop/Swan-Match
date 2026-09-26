#!/bin/sh
# Keep Flutter build outputs off Google Drive / File Provider so codesign
# does not fail with: "resource fork, Finder information, or similar detritus not allowed"
#
# Why: Google Drive attaches com.apple.FinderInfo / com.apple.fileprovider.fpfs#P
# to files under My Drive. Apple's codesign rejects those attributes.
set -e

ROOT_DIR="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"
CACHE_ROOT="${HOME}/Library/Caches/SwanMatchFlutterBuild"
LOCAL_BUILD="${CACHE_ROOT}/build"
TARGET_LINK="${ROOT_DIR}/build"
WRAP_BIN="${CACHE_ROOT}/bin"
DEBUG_LOG="${ROOT_DIR}/.cursor/debug-c1ab8f.log"

mkdir -p "${CACHE_ROOT}" "${ROOT_DIR}/.cursor" "${WRAP_BIN}"

# Install codesign wrapper ahead of /usr/bin in PATH for this build.
cp "${ROOT_DIR}/scripts/codesign_wrap.sh" "${WRAP_BIN}/codesign"
chmod +x "${WRAP_BIN}/codesign" "${ROOT_DIR}/scripts/codesign_wrap.sh"

# If build is a real directory on Drive, migrate it locally then replace with symlink.
if [ -e "${TARGET_LINK}" ] && [ ! -L "${TARGET_LINK}" ]; then
  mkdir -p "${LOCAL_BUILD}"
  if command -v rsync >/dev/null 2>&1; then
    rsync -a "${TARGET_LINK}/" "${LOCAL_BUILD}/" 2>/dev/null || true
  else
    cp -R "${TARGET_LINK}/." "${LOCAL_BUILD}/" 2>/dev/null || true
  fi
  rm -rf "${TARGET_LINK}"
fi

mkdir -p "${LOCAL_BUILD}"
if [ -L "${TARGET_LINK}" ]; then
  current="$(readlink "${TARGET_LINK}" || true)"
  if [ "${current}" != "${LOCAL_BUILD}" ]; then
    rm -f "${TARGET_LINK}"
    ln -s "${LOCAL_BUILD}" "${TARGET_LINK}"
  fi
elif [ ! -e "${TARGET_LINK}" ]; then
  ln -s "${LOCAL_BUILD}" "${TARGET_LINK}"
fi

# Strip residual Finder / File Provider xattrs that break codesign.
xattr -cr "${LOCAL_BUILD}" 2>/dev/null || true
if [ -d "${ROOT_DIR}/ios" ]; then
  # Strip on ios build products that remain under the Drive-backed tree.
  xattr -cr "${ROOT_DIR}/ios/Flutter" 2>/dev/null || true
fi

# #region agent log
ts="$(date +%s)000"
finder_count="$(xattr -lr "${LOCAL_BUILD}/native_assets" 2>/dev/null | grep -c 'com.apple.FinderInfo' || true)"
fpfs_count="$(xattr -lr "${LOCAL_BUILD}/native_assets" 2>/dev/null | grep -c 'com.apple.fileprovider.fpfs' || true)"
is_link="false"
[ -L "${TARGET_LINK}" ] && is_link="true"
printf '{"sessionId":"c1ab8f","runId":"post-fix","hypothesisId":"F","location":"scripts/prepare_ios_codesign.sh","message":"build dir prepared for codesign","data":{"isSymlink":%s,"localPath":"%s","finderInfoCount":%s,"fileProviderCount":%s,"codesignWrap":"%s"},"timestamp":%s}\n' \
  "${is_link}" "${LOCAL_BUILD}" "${finder_count:-0}" "${fpfs_count:-0}" "${WRAP_BIN}/codesign" "${ts}" >> "${DEBUG_LOG}" 2>/dev/null || true
# #endregion

echo "Prepared local build dir at ${LOCAL_BUILD}"
echo "Linked ${TARGET_LINK} -> ${LOCAL_BUILD}"
echo "codesign wrapper at ${WRAP_BIN}/codesign"
