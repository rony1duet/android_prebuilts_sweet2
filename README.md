# android_prebuilts_sweet2

Pinned metadata and verified fetch scripts for sweet2 build-time prebuilts.
This repository intentionally contains **no APKs, native libraries, or other
redistributable proprietary binaries**.

## GCam prebuilt

The current pin is BSG MGC `9.6.080_V52` ENG with package name
`com.google.android.GoogleCameraEng`. Its URL and SHA-256 live in
[`gcam/gcam-prebuilt.env`](gcam/gcam-prebuilt.env).

After syncing this repository, fetch directly into the `GCam_sweet2` source
tree before starting the AOSP/PixelOS build:

```bash
bash vendor/android_prebuilts_sweet2/gcam/fetch_gcam_prebuilt.sh \
  vendor/GCam_sweet2/system/product/app/GoogleCameraEng
```

The script verifies the APK SHA-256, verifies the ZIP structure, and extracts
the APK's arm64 native libraries into `lib/arm64/` below that destination.
It is safe to run repeatedly.

## repo manifest

Copy `manifests/sweet2-prebuilts.xml` to your ROM source tree at
`.repo/local_manifests/sweet2-prebuilts.xml`, then run:

```bash
repo sync vendor/android_prebuilts_sweet2
```

## Updating a prebuilt

1. Download and test the new artifact from its original source.
2. Verify its package name and SHA-256.
3. Update `gcam/gcam-prebuilt.env` in the same commit.
4. Do not commit the downloaded APK or extracted `.so` files.
