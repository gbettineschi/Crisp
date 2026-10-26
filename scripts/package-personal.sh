#!/bin/bash
# Build the fork's existing universal app, disable the upstream update feed,
# then archive that exact signed bundle for the personal release and tap.
set -euo pipefail
cd "$(dirname "$0")/.."
tag="${1:?Usage: scripts/package-personal.sh vX.Y.Z}"
[[ "$tag" =~ ^v(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$ ]] || {
  echo 'Expected a numeric version tag vX.Y.Z.' >&2; exit 1;
}
bash scripts/release.sh "$tag"
app=build/Crisp.app
python3 - "$app/Contents/Info.plist" <<'PY'
import plistlib
from pathlib import Path
import sys
p = Path(sys.argv[1])
info = plistlib.loads(p.read_bytes())
for key in ('SUFeedURL', 'SUPublicEDKey', 'SURequireSignedFeed'):
    info.pop(key, None)
info['SUEnableAutomaticChecks'] = False
info['SUAutomaticallyUpdate'] = False
p.write_bytes(plistlib.dumps(info))
PY
codesign --force --sign - --entitlements Crisp/Crisp.entitlements "$app"
codesign --verify --deep --strict "$app"
for arch in arm64 x86_64; do
  lipo "$app/Contents/MacOS/Crisp" -verify_arch "$arch"
  lipo "$app/Contents/MacOS/crispctl" -verify_arch "$arch"
done
mkdir -p dist
ditto -c -k --sequesterRsrc --keepParent "$app" dist/Crisp-personal.zip
(cd dist && shasum -a 256 Crisp-personal.zip > SHA256SUMS)
# The upstream dry-run DMG was made before our metadata changes; do not ship it.
rm -f Crisp.dmg
