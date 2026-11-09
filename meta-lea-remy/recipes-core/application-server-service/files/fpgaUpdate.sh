#!/usr/bin/bash
# Update FPGA only if build ID in register 0 differs from remy_fpga.zip comment.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FPGA_TOOL="${FPGA_TOOL:-$SCRIPT_DIR/fpgaTool}"
ZIP_FILE="${1:-$SCRIPT_DIR/fpga.zip}"
SVF_NAME="remy_pof.svf"
MAX_ATTEMPTS=10

parse_and_format_build_id_hex() {
    local raw="$1"
    local val

    val="${raw#0x}"
    val="${val#0X}"

    if [[ ! "$val" =~ ^[0-9a-fA-F]+$ ]]; then
        return 1
    fi

    printf '0x%08x' "$((16#$val))"
}

read_zip_build_id() {
    local id

    id="$(unzip -z "$ZIP_FILE" | awk '/^buildId[[:space:]]+/ {print $2; exit}')"
    if [[ -z "$id" ]]; then
        echo "ERROR: Could not find buildId in zip comment: $ZIP_FILE" >&2
        return 1
    fi

    parse_and_format_build_id_hex "$id"
}

read_fpga_build_id() {
    local raw

    raw="$("$FPGA_TOOL" --addr 0x00 --read | awk 'match($0, /0x[0-9A-Fa-f]+/) { print substr($0, RSTART, RLENGTH); exit }')"
    if [[ -z "$raw" ]]; then
        echo "ERROR: Could not parse FPGA build ID from fpgaTool output" >&2
        return 1
    fi

    parse_and_format_build_id_hex "$raw"
}

if [[ ! -x "$FPGA_TOOL" ]]; then
    echo "ERROR: fpgaTool not found or not executable: $FPGA_TOOL" >&2
    exit 1
fi

if [[ ! -f "$ZIP_FILE" ]]; then
    echo "ERROR: Zip file not found: $ZIP_FILE" >&2
    exit 1
fi

zip_id="$(read_zip_build_id)"
fpga_id="$(read_fpga_build_id)"

echo "Zip build ID : $zip_id"
echo "FPGA build ID: $fpga_id"

if [[ "$zip_id" == "$fpga_id" ]]; then
    echo "FPGA is up to date. No programming needed."
    exit 0
fi

echo "Build ID mismatch. Programming FPGA..."

tmpdir="$(mktemp -d)"
cleanup() {
    rm -rf "$tmpdir"
}
trap cleanup EXIT

unzip -jo "$ZIP_FILE" "$SVF_NAME" -d "$tmpdir" >/dev/null

if [[ ! -f "$tmpdir/$SVF_NAME" ]]; then
    echo "ERROR: $SVF_NAME not found in $ZIP_FILE" >&2
    exit 1
fi

attempt=1
while [[ "$attempt" -le "$MAX_ATTEMPTS" ]]; do
    echo "Programming attempt $attempt/$MAX_ATTEMPTS..."

    # fpgaTool uses --svf for programming.
    "$FPGA_TOOL" --svf "$tmpdir/$SVF_NAME" --quiet

    new_fpga_id="$(read_fpga_build_id)"
    echo "FPGA build ID after attempt $attempt: $new_fpga_id"

    if [[ "$new_fpga_id" == "$zip_id" ]]; then
        echo "FPGA update complete."
        exit 0
    fi

    attempt=$((attempt + 1))
done

echo "ERROR: Build ID mismatch persists after $MAX_ATTEMPTS attempts (expected $zip_id, got $new_fpga_id). Rebooting..." >&2
reboot
exit 1
