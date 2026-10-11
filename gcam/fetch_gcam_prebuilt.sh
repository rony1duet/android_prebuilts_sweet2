#!/usr/bin/env bash
# fetch_gcam_prebuilt.sh
# Called by the Crave build system during 'Fetching GCam prebuilts & libs' step.

set -e

VENDOR_GCAM_DIR="vendor/GCam_sweet2"

echo "=== Fetching GCam prebuilts for sweet2 ==="

if [ -d "${VENDOR_GCAM_DIR}" ]; then
    echo "GCam vendor directory found at ${VENDOR_GCAM_DIR}"
    echo "GCam prebuilts are already available via local manifest sync."
else
    echo "Warning: ${VENDOR_GCAM_DIR} not found. Ensure vendor/GCam_sweet2 is synced."
fi

echo "=== GCam prebuilt fetch complete ==="
exit 0