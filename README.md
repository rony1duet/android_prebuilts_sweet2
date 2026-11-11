# Android Prebuilts for Redmi Note 12 Pro 4G (sweet2)

Build-time prebuilt asset management and automated verification tooling for Redmi Note 12 Pro 4G (`sweet2` / Qualcomm SM6150).

This repository contains cryptographic metadata pins and automated fetch scripts. To prevent Git repository bloat, eliminate Git LFS bandwidth limits, and maintain strict copyright hygiene, **no proprietary binaries, APKs, or shared libraries are tracked directly in Git history**.

---

## Architecture Overview

```text
android_prebuilts_sweet2/
├── .gitattributes                  # Enforces UNIX line endings (LF)
├── README.md                       # Repository documentation and integration guide
├── gcam/
│   ├── fetch_gcam_prebuilt.sh      # Automated fetcher, SHA-256 verifier, and arm64 .so extractor
│   └── gcam-prebuilt.env          # Pinned version, SHA-256 checksum, and multi-mirror URLs
└── manifests/
    └── sweet2-prebuilts.xml       # Local manifest snippet for repo sync
```

---

## GCam Prebuilt Tooling

The current pinned camera release is **BSG MGC 9.6.080_V52 ENG** (`com.google.android.GoogleCameraEng`). All source URLs, version tags, and cryptographic hashes are centralized in [`gcam/gcam-prebuilt.env`](gcam/gcam-prebuilt.env).

### Fetcher Mechanism (`fetch_gcam_prebuilt.sh`)

When invoked, the script resolves assets using a prioritized four-stage fallback hierarchy:

1. **Target Verification:** Inspects the destination path (`GoogleCameraEng.apk`). If already present and the SHA-256 matches `GCAM_APK_SHA256`, the download is skipped.
2. **Local Repository Check:** Inspects `gcam/GoogleCameraEng.apk` for pre-cached developer builds.
3. **Host Build Cache:** Checks persistent build caches (`/tmp/gcam_cache/` and `~/.cache/gcam/`) to avoid re-downloading across clean builds.
4. **Multi-Mirror Remote Fetch:**
   - Primary: GitHub Release asset directly from repository releases.
   - Secondary: CelsoAzevedo CDN mirror with anti-hotlinking `Referer` headers.
   - Tertiary: High-speed Pixeldrain CDN mirror.
5. **Integrity & Extraction:**
   - Computes SHA-256 and aborts immediately on checksum mismatch.
   - Validates ZIP archive headers (`unzip -tq`).
   - Extracts all 64-bit native libraries (`lib/arm64-v8a/*.so`) directly into `lib/arm64/` below the destination directory.

---

## ROM Integration (AOSP / PixelOS / LineageOS)

### 1. Local Manifest Setup

Add the repository to your ROM tree's local manifests at `.repo/local_manifests/sweet2-prebuilts.xml`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<manifest>
  <remote name="rony1duet"
          fetch="https://github.com/rony1duet/"
          revision="PixelOS-17-base" />

  <project path="vendor/android_prebuilts_sweet2"
           name="android_prebuilts_sweet2"
           remote="rony1duet"
           revision="PixelOS-17-base" />
</manifest>
```

Sync the repository:
```bash
repo sync vendor/android_prebuilts_sweet2
```

### 2. Pre-Build Hook Execution

Before starting the ROM compilation (`m`, `mka`, or `brunch`), execute the fetch script targeting the `GCam_sweet2` app directory:

```bash
bash vendor/android_prebuilts_sweet2/gcam/fetch_gcam_prebuilt.sh \
    vendor/GCam_sweet2/system/product/app/GoogleCameraEng
```

### 3. Build Automation Example

In automated build scripts (e.g. CI/CD or local build runners), include a setup function before invoking the compiler:

```bash
setup_gcam_prebuilt() {
    local fetcher="vendor/android_prebuilts_sweet2/gcam/fetch_gcam_prebuilt.sh"
    local dest="vendor/GCam_sweet2/system/product/app/GoogleCameraEng"

    if [[ -f "$fetcher" ]]; then
        echo "Preparing GCam prebuilt assets..."
        bash "$fetcher" "$dest"
    fi

    [[ -f "${dest}/GoogleCameraEng.apk" ]] || {
        echo "Error: GoogleCameraEng.apk was not found after running prebuilt fetcher." >&2
        exit 1
    }
}
```

---

## Maintenance & Pin Updates

When updating to a newer GCam APK:

1. Test the candidate APK on a physical device to ensure camera sensors, EIS, and auxiliary lenses function correctly.
2. Compute the SHA-256 hash of the verified APK:
   ```bash
   sha256sum GoogleCameraEng.apk
   ```
3. Update `gcam/gcam-prebuilt.env` with the new version, filenames, URLs, and hash:
   ```bash
   GCAM_VERSION="9.6.080_V53"
   GCAM_APK_NAME="GoogleCameraEng.apk"
   GCAM_APK_URL="https://github.com/rony1duet/android_prebuilts_sweet2/releases/download/v9.6.080_V53/GoogleCameraEng.apk"
   GCAM_APK_SHA256="<new_sha256_hash>"
   ```
4. Verify by running `fetch_gcam_prebuilt.sh` against a temporary directory:
   ```bash
   bash gcam/fetch_gcam_prebuilt.sh /tmp/test_gcam
   ```
5. Commit the updated `.env` file following standard commit conventions:
   ```text
   gcam: update pinned prebuilt to <version>
   ```

---

## License & Attribution

- Automation scripts, configurations, and manifests are licensed under [Apache 2.0](LICENSE).
- Camera applications and binary assets remain the property of their respective upstream authors (Google LLC, BSG / MGC).
