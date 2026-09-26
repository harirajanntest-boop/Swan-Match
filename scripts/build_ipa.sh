#!/bin/sh
# App Store IPA build helper that applies the Google Drive codesign workaround first.
set -e
ROOT_DIR="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

/bin/sh "$ROOT_DIR/scripts/prepare_ios_codesign.sh"
export PATH="${HOME}/Library/Caches/SwanMatchFlutterBuild/bin:${PATH}"
export COPYFILE_DISABLE=1

flutter build ipa --release \
  --build-name=1.0.0 \
  --build-number=12 \
  --export-options-plist=ios/ExportOptions-AppStore.plist

echo "IPA output:"
ls -lh build/ios/ipa/*.ipa
