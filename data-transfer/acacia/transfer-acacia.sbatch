#!/bin/bash

#SBATCH --job-name=rclone_copy
#SBATCH --partition=copy
#SBATCH --time=1-00:00:00
#SBATCH --cpus-per-task=1
#SBATCH --mem=4G
#SBATCH --output=rclone_%j.out
#SBATCH --error=rclone_%j.err

set -euo pipefail

###########################################
# Load rclone module
###########################################
# load rclone module, based on available ones
RCLONE_MODULE=$(module -t avail rclone 2>&1 | grep -oE 'rclone/[0-9][^[:space:]]+' | sort -V | tail -n1)

if [[ -z "$RCLONE_MODULE" ]]; then
    echo "ERROR: No rclone module found."
    echo
    echo "Try:"
    echo "  module spider rclone"
    exit 1
fi

echo "Loading $RCLONE_MODULE"
module load "$RCLONE_MODULE"

usage() {
cat << EOF

==============================================
              RCLONE ACACIA COPY ON SETONIX
==============================================

Usage:
  sbatch --account=<YOUR_PROJECT> transfer-acacia.sbatch \\
      [--dry-run] SOURCE RCLONE_PROFILE BUCKET_NAME DEST_PATH

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
  sbatch --account=pawsey1168 transfer-acacia.sbatch --dry-run \\
      file_name.txt \\
      pawsey1168 \\
      pangenomes \\
      test/my_data/

  # Real copy
  sbatch --account=pawsey1168 transfer-acacia.sbatch \\
      file_name.txt \\
      pawsey1168 \\
      pangenomes \\
      test/my_data/

This copies to:
  pawsey1168:pangenomes/test/my_data/

Make sure pangenomes bucket exists, it can be created with
rclone mkdir pawsey1168:pangenomes/
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
    echo
    echo "Important:"
    echo "  '${BUCKET}' must be an existing Acacia bucket."
    echo "  If you want a folder called '${DEST_PATH}', put it inside an existing bucket."
    echo " This can be created with rclone mkdir, before executing the transfer "
    echo
    echo "Example:"
    echo "  rclone mkdir ${PROFILE}:${BUCKET}/ "
    exit 1
fi

LOG="rclone_copy_$(date +%Y%m%d_%H%M%S).log"

###########################################
# Summary
###########################################

echo
echo "=============================================="
echo "              RCLONE COPY"
echo "=============================================="
echo "Started          : $(date)"
echo "Job ID           : ${SLURM_JOB_ID:-manual}"
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
