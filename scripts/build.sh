#!/bin/bash
# Builds the Godot iOS GameCenter plugin against Godot's own headers and packages it.
# Needs macOS with Xcode and scons (pip install scons). Output: dist/gamecenter-godot<ver>.zip + .sha256
set -euo pipefail

HERE="$(cd "$(dirname "$0")/.." && pwd)"
source "$HERE/build/pins.env"
WORK="${WORK:-$HERE/work}"
DIST="$HERE/dist"
JOBS="$(sysctl -n hw.ncpu)"
GODOT_VERSION="${GODOT_TAG%-stable}"

rm -rf "$WORK" "$DIST"
mkdir -p "$WORK" "$DIST"

checkout() { # repo sha dir
  git init -q "$3"
  git -C "$3" remote add origin "$1"
  git -C "$3" fetch -q --depth 1 origin "$2"
  git -C "$3" checkout -q FETCH_HEAD
  [ "$(git -C "$3" rev-parse HEAD)" = "$2" ] || { echo "checkout of $1 did not land on $2" >&2; exit 1; }
}

echo "::group::Fetch sources"
checkout "$GODOT_IOS_PLUGINS_REPO" "$GODOT_IOS_PLUGINS_SHA" "$WORK/plugins"
checkout "$GODOT_REPO" "$GODOT_SHA" "$WORK/plugins/godot"
echo "::endgroup::"

echo "::group::Generate Godot $GODOT_VERSION headers"
# The plugin only needs Godot's headers, including the generated *.gen.h/*.gen.inc files, which come
# out of a normal iOS build. A trimmed engine is enough; it does not have to link.
pushd "$WORK/plugins/godot" >/dev/null
scons platform=ios target=template_release arch=arm64 ios_simulator=no \
  modules_enabled_by_default=no disable_3d=yes debug_symbols=no -j"$JOBS" -k || echo "engine build did not complete; checking that the headers exist"
for header in core/version_generated.gen.h modules/modules_enabled.gen.h; do
  [ -f "$header" ] || { echo "missing generated header $header" >&2; exit 1; }
done
popd >/dev/null
echo "::endgroup::"

echo "::group::Apply plugin changes and build"
cd "$WORK/plugins"
cp "$HERE/overlay/plugins/gamecenter/"* plugins/gamecenter/
sed -i '' "s/-miphoneos-version-min=12.0/-miphoneos-version-min=$IOS_MIN_VERSION/; s/-mios-simulator-version-min=12.0/-mios-simulator-version-min=$IOS_MIN_VERSION/" SConstruct
grep -q "version-min=$IOS_MIN_VERSION" SConstruct
mkdir -p bin
for target in release release_debug; do
  ./scripts/generate_xcframework.sh gamecenter "$target" 4.0
done
echo "::endgroup::"

echo "::group::Package"
OUT="$WORK/package/gamecenter"
mkdir -p "$OUT"
cp -R bin/gamecenter.release.xcframework "$OUT/gamecenter.release.xcframework"
cp -R bin/gamecenter.release_debug.xcframework "$OUT/gamecenter.debug.xcframework"
cp plugins/gamecenter/gamecenter.gdip "$OUT/"
cp "$HERE/LICENSE" "$WORK/package/LICENSE"
cat > "$WORK/package/BUILD_INFO.txt" <<INFO
plugin:     godot-sdk-integrations/godot-ios-plugins gamecenter @ $GODOT_IOS_PLUGINS_SHA (plus overlay/ from this repo @ ${GITHUB_SHA:-local})
godot:      $GODOT_TAG @ $GODOT_SHA
min iOS:    $IOS_MIN_VERSION
slices:     ios-arm64, ios-arm64_x86_64-simulator
xcode:      $(xcodebuild -version | tr '\n' ' ')
built:      $(date -u +%Y-%m-%dT%H:%M:%SZ)
INFO
ZIP="$DIST/gamecenter-godot$GODOT_VERSION.zip"
(cd "$WORK/package" && zip -qry "$ZIP" .)
(cd "$DIST" && shasum -a 256 "$(basename "$ZIP")" > "$(basename "$ZIP").sha256")
cat "$DIST"/*.sha256
unzip -l "$ZIP"
echo "::endgroup::"
