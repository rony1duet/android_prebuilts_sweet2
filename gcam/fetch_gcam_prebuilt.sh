#!/usr/bin/env bash
# Download and verify the pinned GCam ENG APK, then extract its arm64 libraries.
# Usage: fetch_gcam_prebuilt.sh [GoogleCameraEng destination directory]
set -euo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly REPO_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
# shellcheck source=gcam-prebuilt.env
source "${SCRIPT_DIR}/gcam-prebuilt.env"

readonly DESTINATION="${1:-${GCAM_DESTINATION:-${REPO_DIR}/out/gcam/GoogleCameraEng}}"
readonly APK_DEST="${DESTINATION}/GoogleCameraEng.apk"
readonly LIB_DEST="${DESTINATION}/lib/arm64"

sha256_of() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
  else
    shasum -a 256 "$1" | awk '{print $1}'
  fi
}

download() {
  local destination="$1"
  if command -v curl >/dev/null 2>&1; then
    curl --fail --location --retry 3 --output "$destination" "$GCAM_APK_URL"
  elif command -v wget >/dev/null 2>&1; then
    wget --https-only --tries=3 --output-document="$destination" "$GCAM_APK_URL"
  else
    echo "error: curl or wget is required" >&2
    exit 1
  fi
}

command -v unzip >/dev/null 2>&1 || {
  echo "error: unzip is required" >&2
  exit 1
}

mkdir -p "$DESTINATION" "$LIB_DEST"
if [[ -f "$APK_DEST" ]] && [[ "$(sha256_of "$APK_DEST")" == "$GCAM_APK_SHA256" ]]; then
  echo "Using verified existing ${GCAM_APK_NAME}."
else
  tmp_apk="$(mktemp "${TMPDIR:-/tmp}/${GCAM_APK_NAME}.XXXXXX")"
  trap 'rm -f "$tmp_apk"' EXIT
  echo "Downloading ${GCAM_APK_NAME}..."
  download "$tmp_apk"
  actual_sha256="$(sha256_of "$tmp_apk")"
  if [[ "$actual_sha256" != "$GCAM_APK_SHA256" ]]; then
    echo "error: APK SHA-256 mismatch" >&2
    echo "expected: $GCAM_APK_SHA256" >&2
    echo "actual:   $actual_sha256" >&2
    exit 1
  fi
  mv "$tmp_apk" "$APK_DEST"
  trap - EXIT
fi

unzip -tq "$APK_DEST" >/dev/null
rm -f "$LIB_DEST"/*.so
unzip -j -o "$APK_DEST" 'lib/arm64-v8a/*.so' -d "$LIB_DEST" >/dev/null

lib_count="$(find "$LIB_DEST" -maxdepth 1 -type f -name '*.so' | wc -l | tr -d ' ')"
if [[ "$lib_count" -eq 0 ]]; then
  echo "error: no arm64 native libraries found in the APK" >&2
  exit 1
fi

echo "GCam ${GCAM_VERSION} is ready at: $DESTINATION"
echo "Package: ${GCAM_PACKAGE_NAME}"
echo "SHA-256: $(sha256_of "$APK_DEST")"
echo "Extracted arm64 libraries: $lib_count"
