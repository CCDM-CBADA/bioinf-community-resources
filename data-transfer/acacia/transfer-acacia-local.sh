#!/bin/bash

set -euo pipefail

###########################################
# Check rclone is installed
###########################################

if ! command -v rclone >/dev/null 2>&1; then
    echo "ERROR: rclone is not installed or is not in your PATH."
    echo
    echo "Please install rclone first:"
    echo "  https://rclone.org/downloads/"
    echo
    echo "or ensure it is available in your PATH."
    exit 1
fi

echo "Using rclone: $(command -v rclone)"
echo "Version: $(rclone version | head -n1)"
echo

usage() {
cat << EOF

==============================================
          RCLONE ACACIA COPY - LOCAL
==============================================

Usage:
  bash transfer-acacia-local.sh [--dry-run] SOURCE RCLONE_PROFILE BUCKET_NAME DEST_PATH

Arguments:
  SOURCE
      Local file or directory to copy.

  RCLONE_PROFILE
      Name of the configured rclone profile.
      Example:
          pawsey1168

  BUCKET_NAME
      Existing Acacia bucket name.
      Example:
          pangenomes

  DEST_PATH
      Destination folder/path inside the bucket.
      Example:
          test_data/my_data/

Options:
  --dry-run
      Preview the transfer without copying files.

Examples:

  # Dry run
  bash transfer-acacia-local.sh --dry-run \\
      file_name.txt \\
      pawsey1168 \\
      pangenomes \\
      test/my_data/

  # Real copy
  bash transfer-acacia-local.sh \\
      file_name.txt \\
      pawsey1168 \\
      pangenomes \\
      test/my_data/

This copies to:
  pawsey1168:pangenomes/test/my_data/

==============================================

EOF
exit 1
}

###########################################
# Parse arguments
###########################################

DRY_RUN=""

if [[ "${1:-}" == "--dry-run" ]]; then
    DRY_RUN="--dry-run"
    shift
fi

[[ $# -eq 4 ]] || usage

SOURCE="$1"
PROFILE="$2"
BUCKET="$3"
DEST_PATH="$4"

DEST="${PROFILE}:${BUCKET}/${DEST_PATH}"

###########################################
# Checks
###########################################

if [[ ! -e "$SOURCE" ]]; then
    echo "ERROR: Source does not exist:"
    echo "  $SOURCE"
    exit 1
fi

echo "Checking rclone profile: ${PROFILE}"

if ! PROFILE_ERROR=$(rclone lsd "${PROFILE}:" 2>&1); then
    echo
    echo "ERROR: Cannot access rclone profile '${PROFILE}'."
    echo
    echo "rclone returned:"
    echo "----------------------------------------"
    echo "$PROFILE_ERROR"
    echo "----------------------------------------"
    echo
    echo "Configured profiles:"
    rclone listremotes || true
    exit 1
fi

echo "Profile '${PROFILE}' is accessible."

echo "Checking bucket exists: ${PROFILE}:${BUCKET}"

if ! BUCKET_ERROR=$(rclone lsd "${PROFILE}:${BUCKET}" 2>&1); then
    echo
    echo "ERROR: Cannot access bucket '${BUCKET}' using profile '${PROFILE}'."
    echo
    echo "rclone returned:"
    echo "----------------------------------------"
    echo "$BUCKET_ERROR"
    echo "----------------------------------------"
    echo
    echo "Available buckets for profile '${PROFILE}':"
    rclone lsd "${PROFILE}:" || true
    exit 1
fi

echo "Bucket '${BUCKET}' is accessible."

LOG="rclone_copy_$(date +%Y%m%d_%H%M%S).log"

###########################################
# Summary
###########################################

echo
echo "=============================================="
echo "              RCLONE COPY"
echo "=============================================="
echo "Started          : $(date)"
echo "Source           : $SOURCE"
echo "Profile          : $PROFILE"
echo "Bucket           : $BUCKET"
echo "Destination path : $DEST_PATH"
echo "Full destination : $DEST"
echo "Log file         : $LOG"

if [[ -n "$DRY_RUN" ]]; then
    echo "Mode             : DRY RUN"
else
    echo "Mode             : COPY"
fi

echo "=============================================="

###########################################
# Run rclone copy
###########################################

rclone copy "$SOURCE" "$DEST" \
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
    echo "Copy completed successfully."
fi

echo "Finished : $(date)"
echo "Log file : $LOG"
echo "=============================================="
