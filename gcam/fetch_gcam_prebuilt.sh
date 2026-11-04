#!/usr/bin/env bash
# Download and verify the pinned GCam ENG APK, then extract its arm64 libraries.
# Usage: fetch_gcam_prebuilt.sh [GoogleCameraEng destination directory]
set -euo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly REPO_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Source environment variables safely (stripping any Windows CRLF line endings)
if [[ -f "${SCRIPT_DIR}/gcam-prebuilt.env" ]]; then
  eval "$(tr -d '\r' < "${SCRIPT_DIR}/gcam-prebuilt.env")"
fi

# Sanitize variables of any residual carriage returns
GCAM_VERSION="${GCAM_VERSION%$'\r'}"
GCAM_APK_NAME="${GCAM_APK_NAME%$'\r'}"
GCAM_APK_URL="${GCAM_APK_URL%$'\r'}"
GCAM_APK_MIRROR_URL="${GCAM_APK_MIRROR_URL:-}"
GCAM_APK_MIRROR_URL="${GCAM_APK_MIRROR_URL%$'\r'}"
GCAM_APK_SHA256="${GCAM_APK_SHA256%$'\r'}"
GCAM_PACKAGE_NAME="${GCAM_PACKAGE_NAME%$'\r'}"

readonly DESTINATION="${1:-${GCAM_DESTINATION:-${REPO_DIR}/out/gcam/GoogleCameraEng}}"
readonly APK_DEST="${DESTINATION}/GoogleCameraEng.apk"
readonly LIB_DEST="${DESTINATION}/lib/arm64"
readonly CACHE_DIRS=("/tmp/gcam_cache" "${HOME:-/root}/.cache/gcam")

sha256_of() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
  else
    shasum -a 256 "$1" | awk '{print $1}'
  fi
}

download_file() {
  local target_url="$1"
  local destination="$2"
  mkdir -p "$(dirname "$destination")"
  local curl_args=(-sSL --fail --retry 3 --retry-delay 2 -H "User-Agent: Mozilla/5.0")
  if [[ "$target_url" == *"celsoazevedo.com"* ]]; then
    curl_args+=(-H "Referer: https://www.celsoazevedo.com/files/android/google-camera/dev-bsg/f/dl400/")
  fi
  if command -v curl >/dev/null 2>&1; then
    curl "${curl_args[@]}" --output "$destination" "$target_url"
  elif command -v wget >/dev/null 2>&1; then
    wget -q --https-only --tries=3 --output-document="$destination" "$target_url"
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

# 1. Check if destination APK already exists and is valid
if [[ -f "$APK_DEST" ]] && [[ "$(sha256_of "$APK_DEST")" == "$GCAM_APK_SHA256" ]]; then
  echo "Using verified existing ${GCAM_APK_NAME}."
else
  found_cached=false

  # 2. Check if repository contains the Git LFS prebuilt APK
  local_repo_apk="${SCRIPT_DIR}/GoogleCameraEng.apk"
  if [[ -f "$local_repo_apk" ]] && [[ "$(sha256_of "$local_repo_apk")" == "$GCAM_APK_SHA256" ]]; then
    echo "Using Git LFS prebuilt ${GCAM_APK_NAME} directly from repository."
    cp -f "$local_repo_apk" "$APK_DEST"
    found_cached=true
  fi

  # 3. Check cache directories
  if [[ "$found_cached" != "true" ]]; then
    for cdir in "${CACHE_DIRS[@]}"; do
      cached_file="${cdir}/${GCAM_APK_NAME}"
      if [[ -f "$cached_file" ]] && [[ "$(sha256_of "$cached_file")" == "$GCAM_APK_SHA256" ]]; then
        echo "Using cached ${GCAM_APK_NAME} from ${cached_file}."
        cp -f "$cached_file" "$APK_DEST"
        found_cached=true
        break
      fi
    done
  fi

  # 4. If not found locally or cached, download with mirror fallback
  if [[ "$found_cached" != "true" ]]; then
    tmp_apk="$(mktemp "${TMPDIR:-/tmp}/${GCAM_APK_NAME}.XXXXXX")"
    trap 'rm -f "$tmp_apk"' EXIT

    download_success=false
    urls=("$GCAM_APK_URL")
    if [[ -n "$GCAM_APK_MIRROR_URL" ]]; then
      urls+=("$GCAM_APK_MIRROR_URL")
    fi

    for url in "${urls[@]}"; do
      echo "Attempting to download ${GCAM_APK_NAME} from: ${url}..."
      if download_file "$url" "$tmp_apk"; then
        actual_sha256="$(sha256_of "$tmp_apk")"
        if [[ "$actual_sha256" == "$GCAM_APK_SHA256" ]]; then
          echo "Download successful and SHA-256 verified."
          download_success=true
          break
        else
          echo "Warning: SHA-256 mismatch from ${url} (got ${actual_sha256}), trying next mirror..."
          rm -f "$tmp_apk"
        fi
      else
        echo "Warning: Download failed from ${url}, trying next mirror..."
        rm -f "$tmp_apk"
      fi
    done

    if [[ "$download_success" != "true" ]]; then
      echo "error: failed to download valid ${GCAM_APK_NAME} from all mirrors" >&2
      exit 1
    fi

    mv "$tmp_apk" "$APK_DEST"
    trap - EXIT

    # Populate caches
    for cdir in "${CACHE_DIRS[@]}"; do
      mkdir -p "$cdir" 2>/dev/null || true
      cp -f "$APK_DEST" "${cdir}/${GCAM_APK_NAME}" 2>/dev/null || true
    done
  fi
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
