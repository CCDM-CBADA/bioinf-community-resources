#!/bin/bash

#SBATCH --job-name=rclone_transfer
#SBATCH --partition=copy
#SBATCH --time=1-00:00:00
#SBATCH --cpus-per-task=1
#SBATCH --mem=4G
#SBATCH --output=rclone_%j.out
#SBATCH --error=rclone_%j.err

set -euo pipefail

usage() {
cat << EOF

=========================================================
           RCLONE ACACIA TRANSFER (SLURM)
=========================================================

Description
-----------
Transfer files or directories between the local filesystem
and Pawsey Acacia object storage using rclone.

Usage
-----
sbatch --account=<PROJECT> transfer-acacia.sbatch [--dry-run] \
    <upload|download> SOURCE PROFILE BUCKET DEST_PATH

Arguments
---------
upload | download
    Direction of the transfer.

SOURCE
    upload:
        Local file or directory.

    download:
        File or directory inside the Acacia bucket.

PROFILE
    Name of the configured rclone profile.

    Example:
        pawsey1168

BUCKET
    Existing Acacia bucket.

    Example:
        pangenomes

DEST_PATH
    upload:
        Destination path inside the bucket.

    download:
        Local destination directory.

Options
-------
--dry-run
    Preview the transfer without copying any files.

Examples
--------

Upload a file:

    sbatch --account=pawsey1168 transfer-acacia.sbatch \
        upload \
        file.txt \
        pawsey1168 \
        pangenomes \
        test/

Upload a directory:

    sbatch --account=pawsey1168 transfer-acacia.sbatch \
        upload \
        results/ \
        pawsey1168 \
        pangenomes \
        analysis/run01/

Download a file:

    sbatch --account=pawsey1168 transfer-acacia.sbatch \
        download \
        analysis/run01/file.txt \
        pawsey1168 \
        pangenomes \
        ./downloads/

Download a directory:

    sbatch --account=pawsey1168 transfer-acacia.sbatch \
        download \
        analysis/run01/ \
        pawsey1168 \
        pangenomes \
        ./downloads/

Preview an upload:

    sbatch --account=pawsey1168 transfer-acacia.sbatch \
        --dry-run \
        upload \
        results/ \
        pawsey1168 \
        pangenomes \
        analysis/run01/

Notes
-----
• PROFILE refers to the rclone remote (check with: rclone listremotes)

• BUCKET must already exist.
  List available buckets with:

      rclone lsd <PROFILE>:

• Destination folders inside the bucket are created automatically
  if they do not already exist.

• The script uses 'rclone copy', so existing files are updated,
  but files are never deleted from the destination.

=========================================================

EOF
exit 1
}

# Parse options
DRY_RUN=""

case "${1:-}" in
    -h|--help)
        usage
        ;;
    --dry-run)
        DRY_RUN="--dry-run"
        shift
        ;;
esac

[[ $# -eq 5 ]] || usage

###########################################
# Load rclone module
###########################################
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

###########################################
# Run main transfer script
###########################################

SCRIPT_DIR="${SLURM_SUBMIT_DIR:-$(pwd)}"

if [[ ! -f "${SCRIPT_DIR}/transfer-acacia-local.sh" ]]; then
    echo "ERROR: Cannot find transfer-acacia-local.sh in:"
    echo "  ${SCRIPT_DIR}"
    echo
    echo "Make sure transfer-acacia-local.sh and transfer-acacia.sbatch are in the same directory."
    exit 1
fi

bash "${SCRIPT_DIR}/transfer-acacia-local.sh" "$@"
