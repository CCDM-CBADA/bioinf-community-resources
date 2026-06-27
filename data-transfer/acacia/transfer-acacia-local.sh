#!/bin/bash

set -euo pipefail

usage() {
cat << EOF

==============================================
          RCLONE ACACIA TRANSFER
==============================================

Usage:
  bash transfer-acacia-local.sh [--dry-run] upload   SOURCE PROFILE BUCKET DEST_PATH
  bash transfer-acacia-local.sh [--dry-run] download SOURCE PROFILE BUCKET DEST_PATH

Arguments:
  DIRECTION
      upload or download

  SOURCE
      For upload:   local file or directory
      For download: path inside the Acacia bucket

  PROFILE
      Rclone profile name
      Example: pawsey1168

  BUCKET
      Existing Acacia bucket name
      Example: pangenomes

  DEST_PATH
      For upload:   destination path inside the bucket
      For download: local destination path

Examples:

  Upload one file:
    bash transfer-acacia-local.sh upload \\
        file_name.txt pawsey1168 pangenomes test/

  Upload one directory:
    bash transfer-acacia-local.sh upload \\
        results/ pawsey1168 pangenomes test/results/

  Download one file:
    bash transfer-acacia-local.sh download \\
        test/file_name.txt pawsey1168 pangenomes ./downloads/

  Download one directory:
    bash transfer-acacia-local.sh download \\
        test/results/ pawsey1168 pangenomes ./downloads/results/

  Dry run:
    bash transfer-acacia-local.sh --dry-run upload \\
        file_name.txt pawsey1168 pangenomes test/

==============================================

EOF
exit 1
}

###########################################
# Check rclone exists
###########################################

if ! command -v rclone >/dev/null 2>&1; then
    echo "ERROR: rclone is not installed or not in PATH."
    exit 1
fi

echo "Using rclone: $(command -v rclone)"
echo "Version: $(rclone version | head -n1)"

###########################################
# Parse arguments
###########################################

DRY_RUN=""

if [[ "${1:-}" == "--dry-run" ]]; then
    DRY_RUN="--dry-run"
    shift
fi

[[ $# -eq 5 ]] || usage

DIRECTION="$1"
SOURCE="$2"
PROFILE="$3"
BUCKET="$4"
DEST_PATH="$5"

###########################################
# Check profile and bucket
###########################################

echo
echo "Checking rclone profile: ${PROFILE}"

if ! PROFILE_ERROR=$(rclone lsd "${PROFILE}:" 2>&1); then
    echo
    echo "ERROR: Cannot access rclone profile '${PROFILE}'."
    echo "$PROFILE_ERROR"
    echo
    echo "Configured profiles:"
    rclone listremotes || true
    exit 1
fi

echo "Profile '${PROFILE}' is accessible."

echo
echo "Checking bucket exists: ${PROFILE}:${BUCKET}"

if ! BUCKET_ERROR=$(rclone lsd "${PROFILE}:${BUCKET}" 2>&1); then
    echo
    echo "ERROR: Cannot access bucket '${BUCKET}' using profile '${PROFILE}'."
    echo "$BUCKET_ERROR"
    echo
    echo "Available buckets:"
    rclone lsd "${PROFILE}:" || true
    exit 1
fi

echo "Bucket '${BUCKET}' is accessible."

###########################################
# Build source and destination
###########################################

case "$DIRECTION" in
    upload)
        if [[ ! -e "$SOURCE" ]]; then
            echo "ERROR: Local source does not exist:"
            echo "  $SOURCE"
            exit 1
        fi

        SRC="$SOURCE"
        DEST="${PROFILE}:${BUCKET}/${DEST_PATH}"
        ;;

    download)
        SRC="${PROFILE}:${BUCKET}/${SOURCE}"
        DEST="$DEST_PATH"

        echo
        echo "Checking remote source: $SRC"

        if rclone lsf "$SRC" >/dev/null 2>&1; then
            REMOTE_LIST=$(rclone lsf "$SRC" --recursive 2>/dev/null || true)
        else
            echo "ERROR: Cannot access remote source:"
            echo "  $SRC"
            exit 1
        fi

        if [[ -z "$REMOTE_LIST" ]]; then
            echo "ERROR: Remote source appears empty or does not exist:"
            echo "  $SRC"
            echo
            echo "Check available files with:"
            echo "  rclone lsf ${PROFILE}:${BUCKET}/ --recursive | head"
            exit 1
        fi

        echo "Remote source contains:"
        echo "$REMOTE_LIST" | head
        ;;

    *)
        echo "ERROR: Direction must be either 'upload' or 'download'."
        usage
        ;;
esac

LOG="rclone_${DIRECTION}_$(date +%Y%m%d_%H%M%S).log"

###########################################
# Summary
###########################################

echo
echo "=============================================="
echo "              RCLONE TRANSFER"
echo "=============================================="
echo "Started          : $(date)"
echo "Direction        : $DIRECTION"
echo "Source           : $SRC"
echo "Destination      : $DEST"
echo "Profile          : $PROFILE"
echo "Bucket           : $BUCKET"
echo "Log file         : $LOG"

if [[ -n "$DRY_RUN" ]]; then
    echo "Mode             : DRY RUN"
else
    echo "Mode             : COPY"
fi

echo "=============================================="

###########################################
# Transfer
###########################################

rclone copy "$SRC" "$DEST" \
    ${DRY_RUN} \
    --progress \
    --checksum \
    --create-empty-src-dirs \
    --log-file="$LOG" \
    --log-level=INFO

###########################################
# Finish
###########################################

echo
echo "=============================================="

if [[ -n "$DRY_RUN" ]]; then
    echo "Dry run completed successfully."
    echo "No files were copied."
else
    echo "Transfer completed successfully."
fi

echo "Finished : $(date)"
echo "Log file : $LOG"
echo "=============================================="
